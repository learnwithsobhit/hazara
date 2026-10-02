//! File-backed store. One JSON file per concern:
//!  - `{dir}/guests.json`  — all guest sessions (compact)
//!  - `{dir}/rooms.json`   — all lobby rooms (compact)
//!  - `{dir}/{id}.match`   — one file per live match (compact)
//!
//! Writes are atomic (write-tmp → rename). The whole world is never rewritten
//! for a single match move, so draft saves are cheap.

use std::collections::HashMap;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use tokio::sync::Mutex;
use uuid::Uuid;

use crate::table::SavedTable;

use async_trait::async_trait;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SavedGuest {
    pub id: Uuid,
    pub name: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SavedRoom {
    pub code: String,
    pub host: Uuid,
    pub length: String,
    pub match_id: Option<Uuid>,
    pub seats: Vec<Option<SavedGuest>>,
    /// UTC millis when the room was last modified. Used for GC.
    #[serde(default)]
    pub updated_ms: u64,
}

/// Persistence front for lobby + match files. `FileStore` is the production
/// implementation; tests may substitute an in-memory double later.
#[async_trait]
pub trait MatchStore: Send + Sync {
    async fn put_guest(&self, token: &str, guest: SavedGuest) -> Result<(), String>;
    async fn put_room(&self, room: SavedRoom) -> Result<(), String>;
    async fn put_match(&self, id: Uuid, table: SavedTable) -> Result<(), String>;
    async fn lobby_snapshot(&self) -> (HashMap<String, SavedGuest>, HashMap<String, SavedRoom>);
    async fn load_matches(&self) -> HashMap<String, SavedTable>;
    async fn reap(&self, max_room_idle_ms: u64, max_match_done_ms: u64) -> (usize, usize);
}

#[async_trait]
impl MatchStore for FileStore {
    async fn put_guest(&self, token: &str, guest: SavedGuest) -> Result<(), String> {
        FileStore::put_guest(self, token, guest).await
    }
    async fn put_room(&self, room: SavedRoom) -> Result<(), String> {
        FileStore::put_room(self, room).await
    }
    async fn put_match(&self, id: Uuid, table: SavedTable) -> Result<(), String> {
        FileStore::put_match(self, id, table).await
    }
    async fn lobby_snapshot(&self) -> (HashMap<String, SavedGuest>, HashMap<String, SavedRoom>) {
        FileStore::lobby_snapshot(self).await
    }
    async fn load_matches(&self) -> HashMap<String, SavedTable> {
        FileStore::load_matches(self).await
    }
    async fn reap(&self, max_room_idle_ms: u64, max_match_done_ms: u64) -> (usize, usize) {
        FileStore::reap(self, max_room_idle_ms, max_match_done_ms).await
    }
}

pub struct FileStore {
    dir: PathBuf,
    /// Guests and rooms share a lobby lock; matches are independent files.
    lobby: Mutex<LobbyState>,
}

#[derive(Default)]
struct LobbyState {
    guests: HashMap<String, SavedGuest>,
    rooms: HashMap<String, SavedRoom>,
}

fn now_ms() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0)
}

impl FileStore {
    pub async fn open(dir: impl AsRef<Path>) -> Result<Self, String> {
        let dir = dir.as_ref().to_path_buf();
        tokio::fs::create_dir_all(&dir)
            .await
            .map_err(|e| format!("Could not create save folder: {e}"))?;

        let guests = read_json::<HashMap<String, SavedGuest>>(&dir.join("guests.json"))
            .await
            .unwrap_or_default();
        let rooms = read_json::<HashMap<String, SavedRoom>>(&dir.join("rooms.json"))
            .await
            .unwrap_or_default();

        Ok(Self {
            dir,
            lobby: Mutex::new(LobbyState { guests, rooms }),
        })
    }

    /// Load all match files from the store directory. Called once at boot.
    pub async fn load_matches(&self) -> HashMap<String, SavedTable> {
        let mut out = HashMap::new();
        let Ok(mut entries) = tokio::fs::read_dir(&self.dir).await else {
            return out;
        };
        while let Ok(Some(entry)) = entries.next_entry().await {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) != Some("match") {
                continue;
            }
            let Some(stem) = path.file_stem().and_then(|s| s.to_str()) else {
                continue;
            };
            if let Ok(table) = read_json::<SavedTable>(&path).await {
                out.insert(stem.to_string(), table);
            }
        }
        out
    }

    /// Snapshot of guests and rooms for boot-time restore.
    pub async fn lobby_snapshot(
        &self,
    ) -> (HashMap<String, SavedGuest>, HashMap<String, SavedRoom>) {
        let state = self.lobby.lock().await;
        (state.guests.clone(), state.rooms.clone())
    }

    pub async fn put_guest(&self, token: &str, guest: SavedGuest) -> Result<(), String> {
        let mut state = self.lobby.lock().await;
        state.guests.insert(token.to_string(), guest);
        write_json(&self.dir.join("guests.json"), &state.guests).await
    }

    pub async fn put_room(&self, room: SavedRoom) -> Result<(), String> {
        let mut state = self.lobby.lock().await;
        state.rooms.insert(room.code.clone(), room);
        write_json(&self.dir.join("rooms.json"), &state.rooms).await
    }

    #[allow(dead_code)]
    pub async fn remove_room(&self, code: &str) -> Result<(), String> {
        let mut state = self.lobby.lock().await;
        state.rooms.remove(code);
        write_json(&self.dir.join("rooms.json"), &state.rooms).await
    }

    pub async fn put_match(&self, id: Uuid, table: SavedTable) -> Result<(), String> {
        let path = self.dir.join(format!("{id}.match"));
        write_json(&path, &table).await
    }

    #[allow(dead_code)]
    pub async fn remove_match(&self, id: Uuid) {
        let path = self.dir.join(format!("{id}.match"));
        let _ = tokio::fs::remove_file(path).await;
    }

    /// Delete empty lobby rooms older than `max_age_ms` and their match files if
    /// the match is over. Returns counts for logging.
    pub async fn reap(&self, max_room_idle_ms: u64, max_match_done_ms: u64) -> (usize, usize) {
        let now = now_ms();
        let mut rooms_reaped = 0usize;
        let mut matches_reaped = 0usize;
        {
            let mut state = self.lobby.lock().await;
            let before = state.rooms.len();
            state.rooms.retain(|_code, room| {
                // Keep rooms that have an active match reference (match actor handles its own lifetime).
                if room.match_id.is_some() {
                    return true;
                }
                // Reap empty lobby rooms with no players that are stale.
                let filled = room.seats.iter().filter(|s| s.is_some()).count();
                let age = now.saturating_sub(room.updated_ms);
                // Keep if recently active or has any seated players.
                filled > 0 && age < max_room_idle_ms || age < 60_000
            });
            let removed = before - state.rooms.len();
            if removed > 0 {
                rooms_reaped = removed;
                let _ = write_json(&self.dir.join("rooms.json"), &state.rooms).await;
            }
        }
        // Reap stale .match files for matches that completed long ago.
        // We can't know if they're done from here, so we rely on remove_match
        // being called when a match actor exits after Summary phase.
        // This is a safety net for orphaned files.
        let Ok(mut entries) = tokio::fs::read_dir(&self.dir).await else {
            return (rooms_reaped, matches_reaped);
        };
        while let Ok(Some(entry)) = entries.next_entry().await {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) != Some("match") {
                continue;
            }
            let Ok(meta) = tokio::fs::metadata(&path).await else {
                continue;
            };
            let Ok(modified) = meta.modified() else {
                continue;
            };
            let Ok(elapsed) = modified.elapsed() else {
                continue;
            };
            if elapsed.as_millis() as u64 > max_match_done_ms
                && tokio::fs::remove_file(&path).await.is_ok()
            {
                matches_reaped += 1;
            }
        }
        (rooms_reaped, matches_reaped)
    }
}

async fn read_json<T: serde::de::DeserializeOwned>(path: &Path) -> Result<T, String> {
    let bytes = tokio::fs::read(path)
        .await
        .map_err(|e| format!("read {}: {e}", path.display()))?;
    serde_json::from_slice(&bytes).map_err(|e| format!("parse {}: {e}", path.display()))
}

async fn write_json<T: Serialize>(path: &Path, value: &T) -> Result<(), String> {
    let bytes =
        serde_json::to_vec(value).map_err(|e| format!("serialize {}: {e}", path.display()))?;
    let tmp = path.with_extension("tmp");
    tokio::fs::write(&tmp, &bytes)
        .await
        .map_err(|e| format!("write tmp {}: {e}", tmp.display()))?;
    tokio::fs::rename(&tmp, path)
        .await
        .map_err(|e| format!("rename to {}: {e}", path.display()))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::table::{Length, Seat, SeatStatus, Table};
    use hazara_domain::standard_deck;

    #[tokio::test]
    async fn reopen_restores_the_guest_and_the_hand() {
        let dir = std::env::temp_dir().join(format!("hazara-test-{}", Uuid::new_v4()));
        tokio::fs::create_dir_all(&dir).await.unwrap();
        let store = FileStore::open(&dir).await.unwrap();
        let guest_id = Uuid::new_v4();
        store
            .put_guest(
                "token-1",
                SavedGuest {
                    id: guest_id,
                    name: "Ada".into(),
                },
            )
            .await
            .unwrap();
        let deck = standard_deck();
        let holes = [
            deck[0..13].to_vec(),
            deck[13..26].to_vec(),
            deck[26..39].to_vec(),
            deck[39..52].to_vec(),
        ];
        let seats = ["Ada", "Bo", "Cy", "Di"].map(|name| Seat {
            player_id: Uuid::new_v4(),
            name: name.into(),
            status: SeatStatus::Arranging,
        });
        let table = Table::from_holes(seats, Length::OneDeal, holes);
        let hand = table.snapshot(0).hand.clone();
        let match_id = Uuid::new_v4();
        store.put_match(match_id, table.export()).await.unwrap();
        drop(store);

        let store = FileStore::open(&dir).await.unwrap();
        let (guests, _) = store.lobby_snapshot().await;
        assert_eq!(guests["token-1"].name, "Ada");
        let matches = store.load_matches().await;
        let restored = Table::restore(&matches[&match_id.to_string()]).unwrap();
        assert_eq!(restored.snapshot(0).hand, hand);
        assert!(restored.snapshot(0).hand.iter().all(|id| !id.is_empty()));
        let _ = tokio::fs::remove_dir_all(&dir).await;
    }
}
