//! `MatchStore` backed by Postgres. Used when `DATABASE_URL` is set.
//! The snapshot JSON contains private cards and is not logged.

use std::collections::HashMap;
use std::path::Path;

use async_trait::async_trait;
use hazara_persistence::{MatchWrite, PgStore, RoomWrite};
use uuid::Uuid;

use crate::store::{MatchStore, SavedGuest, SavedRoom};
use crate::table::SavedTable;

pub struct PostgresStore {
    inner: PgStore,
}

impl PostgresStore {
    pub async fn open(database_url: &str, migrations_dir: &Path) -> Result<Self, String> {
        let inner = PgStore::connect(database_url).await?;
        inner.migrate(migrations_dir).await?;
        Ok(Self { inner })
    }
}

#[async_trait]
impl MatchStore for PostgresStore {
    async fn put_guest(&self, token: &str, guest: SavedGuest) -> Result<(), String> {
        self.inner.upsert_guest(token, guest.id, &guest.name).await
    }

    async fn put_room(&self, room: SavedRoom) -> Result<(), String> {
        self.inner
            .upsert_room(&RoomWrite {
                code: room.code,
                host: room.host,
                length: room.length,
                match_id: room.match_id,
                updated_ms: room.updated_ms,
                seats: room
                    .seats
                    .into_iter()
                    .map(|seat| seat.map(|person| (person.id, person.name)))
                    .collect(),
            })
            .await
    }

    async fn put_match(&self, id: Uuid, table: SavedTable) -> Result<(), String> {
        let finished = table_finished(&table);
        let seats = table.seats.clone().map(|seat| (seat.player_id, seat.name));
        let state = serde_json::to_value(&table).map_err(|_| "could not save match".to_string())?;
        self.inner
            .upsert_match(
                id,
                &state,
                &MatchWrite {
                    phase: table.phase,
                    length: table.length,
                    totals: table.totals,
                    finished,
                    seats,
                },
            )
            .await
    }

    async fn lobby_snapshot(&self) -> (HashMap<String, SavedGuest>, HashMap<String, SavedRoom>) {
        let guests = match self.inner.load_guests().await {
            Ok(rows) => rows
                .into_iter()
                .map(|row| {
                    (
                        row.token,
                        SavedGuest {
                            id: row.id,
                            name: row.name,
                        },
                    )
                })
                .collect(),
            Err(message) => {
                tracing::error!(error = %message, "could not load guests");
                HashMap::new()
            }
        };
        let rooms = match self.inner.load_rooms().await {
            Ok(rows) => rows
                .into_iter()
                .map(|row| {
                    (
                        row.code.clone(),
                        SavedRoom {
                            code: row.code,
                            host: row.host,
                            length: row.length,
                            match_id: row.match_id,
                            seats: row
                                .seats
                                .into_iter()
                                .map(|seat| seat.map(|(id, name)| SavedGuest { id, name }))
                                .collect(),
                            updated_ms: row.updated_ms,
                        },
                    )
                })
                .collect(),
            Err(message) => {
                tracing::error!(error = %message, "could not load rooms");
                HashMap::new()
            }
        };
        (guests, rooms)
    }

    async fn load_matches(&self) -> HashMap<String, SavedTable> {
        match self.inner.load_active_matches().await {
            Ok(rows) => {
                let mut out = HashMap::new();
                for (id, state) in rows {
                    match serde_json::from_value::<SavedTable>(state) {
                        Ok(table) => {
                            out.insert(id.to_string(), table);
                        }
                        Err(_) => tracing::warn!(%id, "skipped unreadable match"),
                    }
                }
                out
            }
            Err(message) => {
                tracing::error!(error = %message, "could not load matches");
                HashMap::new()
            }
        }
    }

    async fn reap(&self, max_room_idle_ms: u64, max_match_done_ms: u64) -> (usize, usize) {
        match self.inner.reap(max_room_idle_ms, max_match_done_ms).await {
            Ok(counts) => counts,
            Err(message) => {
                tracing::error!(error = %message, "reap failed");
                (0, 0)
            }
        }
    }
}

/// Same end condition as `Table::is_over`, read from the durable snapshot.
fn table_finished(table: &SavedTable) -> bool {
    if table.force_ended && table.phase == "summary" {
        return true;
    }
    match table.length.as_str() {
        "one_deal" => table.deal_no >= 1 && table.phase == "summary",
        "short" => table.deal_no >= 3 && table.phase == "summary",
        "full" => {
            let max = table.totals.iter().copied().max().unwrap_or(0);
            max >= 1000 && table.totals.iter().filter(|score| **score == max).count() == 1
        }
        _ => false,
    }
}
