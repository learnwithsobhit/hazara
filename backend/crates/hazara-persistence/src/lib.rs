//! PostgreSQL store for HAZARA guests, rooms, and match snapshots.
//!
//! `matches.state` holds a `SavedTable`, including private cards. Callers must
//! not log that JSON. Database errors returned here are short context strings;
//! the driver message is traced without the bound snapshot.

use std::collections::HashMap;
use std::path::Path;

use sqlx::postgres::PgPoolOptions;
use sqlx::{PgPool, Row};
use uuid::Uuid;

#[derive(Clone, Debug)]
pub struct GuestRow {
    pub token: String,
    pub id: Uuid,
    pub name: String,
}

#[derive(Clone, Debug)]
pub struct SeatRow {
    pub seat: i16,
    pub player_id: Uuid,
    pub name: String,
}

#[derive(Clone, Debug)]
pub struct RoomRow {
    pub code: String,
    pub host: Uuid,
    pub length: String,
    pub match_id: Option<Uuid>,
    pub updated_ms: u64,
    pub seats: Vec<Option<(Uuid, String)>>,
}

#[derive(Clone, Debug)]
pub struct RoomWrite {
    pub code: String,
    pub host: Uuid,
    pub length: String,
    pub match_id: Option<Uuid>,
    pub updated_ms: u64,
    pub seats: Vec<Option<(Uuid, String)>>,
}

#[derive(Clone, Debug)]
pub struct MatchWrite {
    pub phase: String,
    pub length: String,
    pub totals: [u16; 4],
    pub finished: bool,
    pub seats: [(Uuid, String); 4],
}

#[derive(Clone)]
pub struct PgStore {
    pool: PgPool,
}

impl PgStore {
    pub async fn connect(database_url: &str) -> Result<Self, String> {
        let pool = PgPoolOptions::new()
            .max_connections(10)
            .acquire_timeout(std::time::Duration::from_secs(5))
            .idle_timeout(std::time::Duration::from_secs(60))
            .max_lifetime(std::time::Duration::from_secs(30 * 60))
            .test_before_acquire(true)
            .after_connect(|conn, _meta| {
                Box::pin(async move {
                    sqlx::query("SET statement_timeout = '3s'")
                        .execute(&mut *conn)
                        .await?;
                    Ok(())
                })
            })
            .connect(database_url)
            .await
            .map_err(|err| db_err("could not connect to postgres", err))?;
        Ok(Self { pool })
    }

    pub async fn migrate(&self, migrations_dir: impl AsRef<Path>) -> Result<(), String> {
        let dir = migrations_dir.as_ref();
        let migrator = sqlx::migrate::Migrator::new(dir).await.map_err(|err| {
            tracing::error!(error = %err, dir = %dir.display(), "migration load failed");
            "could not load migrations".to_string()
        })?;
        migrator.run(&self.pool).await.map_err(|err| {
            tracing::error!(error = %err, "migration failed");
            "could not migrate postgres".to_string()
        })?;
        Ok(())
    }

    pub async fn upsert_guest(&self, token: &str, id: Uuid, name: &str) -> Result<(), String> {
        sqlx::query(
            r#"
            INSERT INTO guest_sessions (session_id, token, name)
            VALUES ($1, $2, $3)
            ON CONFLICT (session_id) DO UPDATE
                SET token = EXCLUDED.token,
                    name = EXCLUDED.name
            "#,
        )
        .bind(id)
        .bind(token)
        .bind(name)
        .execute(&self.pool)
        .await
        .map_err(|err| db_err("could not save guest", err))?;
        Ok(())
    }

    pub async fn upsert_room(&self, room: &RoomWrite) -> Result<(), String> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|err| db_err("could not save room", err))?;
        sqlx::query(
            r#"
            INSERT INTO rooms (code, host_session_id, match_length, match_id, updated_at)
            VALUES (
                $1,
                $2,
                $3,
                $4,
                CASE
                    WHEN $5::bigint <= 0 THEN now()
                    ELSE to_timestamp($5::double precision / 1000.0)
                END
            )
            ON CONFLICT (code) DO UPDATE SET
                host_session_id = EXCLUDED.host_session_id,
                match_length = EXCLUDED.match_length,
                match_id = EXCLUDED.match_id,
                updated_at = EXCLUDED.updated_at
            "#,
        )
        .bind(&room.code)
        .bind(room.host)
        .bind(&room.length)
        .bind(room.match_id)
        .bind(room.updated_ms as i64)
        .execute(&mut *tx)
        .await
        .map_err(|err| db_err("could not save room", err))?;

        sqlx::query("DELETE FROM room_seats WHERE code = $1")
            .bind(&room.code)
            .execute(&mut *tx)
            .await
            .map_err(|err| db_err("could not save room", err))?;

        for (index, seat) in room.seats.iter().enumerate() {
            let Some((player_id, name)) = seat else {
                continue;
            };
            sqlx::query(
                r#"
                INSERT INTO room_seats (code, seat, player_id, name)
                VALUES ($1, $2, $3, $4)
                "#,
            )
            .bind(&room.code)
            .bind(index as i16)
            .bind(player_id)
            .bind(name)
            .execute(&mut *tx)
            .await
            .map_err(|err| db_err("could not save room", err))?;
        }

        if let Some(match_id) = room.match_id {
            sqlx::query("UPDATE matches SET room_code = $1 WHERE match_id = $2")
                .bind(&room.code)
                .bind(match_id)
                .execute(&mut *tx)
                .await
                .map_err(|err| db_err("could not save room", err))?;
        }

        tx.commit()
            .await
            .map_err(|err| db_err("could not save room", err))?;
        Ok(())
    }

    pub async fn upsert_match(
        &self,
        id: Uuid,
        state: &serde_json::Value,
        meta: &MatchWrite,
    ) -> Result<(), String> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|err| db_err("could not save match", err))?;
        sqlx::query(
            r#"
            INSERT INTO matches (
                match_id, status, phase, length, state_version, state, finished_at
            )
            VALUES (
                $1,
                CASE WHEN $2 THEN 'finished' ELSE 'active' END,
                $3,
                $4,
                1,
                $5,
                CASE WHEN $2 THEN now() ELSE NULL END
            )
            ON CONFLICT (match_id) DO UPDATE SET
                phase = EXCLUDED.phase,
                length = EXCLUDED.length,
                state = EXCLUDED.state,
                state_version = matches.state_version + 1,
                status = CASE
                    WHEN $2 OR matches.status = 'finished' THEN 'finished'
                    ELSE 'active'
                END,
                updated_at = now(),
                finished_at = CASE
                    WHEN $2 OR matches.status = 'finished'
                        THEN COALESCE(matches.finished_at, now())
                    ELSE matches.finished_at
                END
            "#,
        )
        .bind(id)
        .bind(meta.finished)
        .bind(&meta.phase)
        .bind(&meta.length)
        .bind(sqlx::types::Json(state.clone()))
        .execute(&mut *tx)
        .await
        .map_err(|err| db_err("could not save match", err))?;

        sqlx::query("DELETE FROM match_players WHERE match_id = $1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(|err| db_err("could not save match", err))?;
        for (seat, (player_id, name)) in meta.seats.iter().enumerate() {
            sqlx::query(
                r#"
                INSERT INTO match_players (match_id, player_id, name, seat)
                VALUES ($1, $2, $3, $4)
                "#,
            )
            .bind(id)
            .bind(player_id)
            .bind(name)
            .bind(seat as i16)
            .execute(&mut *tx)
            .await
            .map_err(|err| db_err("could not save match", err))?;
        }

        if meta.finished {
            let totals = serde_json::json!(meta.totals);
            sqlx::query(
                r#"
                INSERT INTO match_results (match_id, totals)
                VALUES ($1, $2)
                ON CONFLICT (match_id) DO UPDATE SET totals = EXCLUDED.totals
                "#,
            )
            .bind(id)
            .bind(sqlx::types::Json(totals))
            .execute(&mut *tx)
            .await
            .map_err(|err| db_err("could not save match", err))?;
        }

        tx.commit()
            .await
            .map_err(|err| db_err("could not save match", err))?;
        Ok(())
    }

    pub async fn load_guests(&self) -> Result<Vec<GuestRow>, String> {
        let rows = sqlx::query("SELECT token, session_id, name FROM guest_sessions")
            .fetch_all(&self.pool)
            .await
            .map_err(|err| db_err("could not load guests", err))?;
        Ok(rows
            .into_iter()
            .map(|row| GuestRow {
                token: row.get("token"),
                id: row.get("session_id"),
                name: row.get("name"),
            })
            .collect())
    }

    pub async fn load_rooms(&self) -> Result<Vec<RoomRow>, String> {
        let rooms = sqlx::query(
            r#"
            SELECT code, host_session_id, match_length, match_id,
                   (EXTRACT(EPOCH FROM updated_at) * 1000)::bigint AS updated_ms
            FROM rooms
            "#,
        )
        .fetch_all(&self.pool)
        .await
        .map_err(|err| db_err("could not load rooms", err))?;
        let seats = sqlx::query("SELECT code, seat, player_id, name FROM room_seats")
            .fetch_all(&self.pool)
            .await
            .map_err(|err| db_err("could not load rooms", err))?;
        let mut by_code: HashMap<String, Vec<Option<(Uuid, String)>>> = HashMap::new();
        for row in seats {
            let code: String = row.get("code");
            let seat: i16 = row.get("seat");
            let slots = by_code.entry(code).or_insert_with(|| vec![None; 4]);
            if (0..4).contains(&seat) {
                slots[seat as usize] = Some((row.get("player_id"), row.get("name")));
            }
        }
        Ok(rooms
            .into_iter()
            .map(|row| {
                let code: String = row.get("code");
                let updated: i64 = row.get("updated_ms");
                RoomRow {
                    seats: by_code.remove(&code).unwrap_or_else(|| vec![None; 4]),
                    code,
                    host: row.get("host_session_id"),
                    length: row.get("match_length"),
                    match_id: row.get("match_id"),
                    updated_ms: updated.max(0) as u64,
                }
            })
            .collect())
    }

    /// Active matches only. The JSON value is a private `SavedTable`.
    pub async fn load_active_matches(&self) -> Result<Vec<(Uuid, serde_json::Value)>, String> {
        let rows = sqlx::query("SELECT match_id, state FROM matches WHERE status = 'active'")
            .fetch_all(&self.pool)
            .await
            .map_err(|err| db_err("could not load matches", err))?;
        Ok(rows
            .into_iter()
            .map(|row| {
                let id: Uuid = row.get("match_id");
                let state: sqlx::types::Json<serde_json::Value> = row.get("state");
                (id, state.0)
            })
            .collect())
    }

    pub async fn reap(
        &self,
        max_room_idle_ms: u64,
        max_match_done_ms: u64,
    ) -> Result<(usize, usize), String> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|err| db_err("could not reap", err))?;
        let rooms = sqlx::query(
            r#"
            DELETE FROM rooms r
            WHERE r.match_id IS NULL
              AND r.updated_at <= now() - interval '60 seconds'
              AND (
                NOT EXISTS (SELECT 1 FROM room_seats s WHERE s.code = r.code)
                OR r.updated_at <= now() - make_interval(secs => $1::double precision / 1000.0)
              )
            "#,
        )
        .bind(max_room_idle_ms as f64)
        .execute(&mut *tx)
        .await
        .map_err(|err| db_err("could not reap", err))?;
        let matches = sqlx::query(
            r#"
            DELETE FROM matches
            WHERE status = 'finished'
              AND COALESCE(finished_at, updated_at)
                  <= now() - make_interval(secs => $1::double precision / 1000.0)
            "#,
        )
        .bind(max_match_done_ms as f64)
        .execute(&mut *tx)
        .await
        .map_err(|err| db_err("could not reap", err))?;
        tx.commit()
            .await
            .map_err(|err| db_err("could not reap", err))?;
        Ok((
            rooms.rows_affected() as usize,
            matches.rows_affected() as usize,
        ))
    }
}

fn db_err(context: &str, err: sqlx::Error) -> String {
    let detail = err
        .as_database_error()
        .map(|db| db.message().to_string())
        .unwrap_or_else(|| err.to_string());
    tracing::error!(error = %detail, "{context}");
    context.to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn round_trip_when_database_url_is_set() {
        let Ok(url) = std::env::var("DATABASE_URL") else {
            return;
        };
        if url.trim().is_empty() {
            return;
        }
        let store = PgStore::connect(&url).await.expect("connect");
        let migrations = Path::new(env!("CARGO_MANIFEST_DIR")).join("migrations");
        store.migrate(&migrations).await.expect("migrate");

        let ids: [Uuid; 4] = std::array::from_fn(|_| Uuid::new_v4());
        let names = ["Ada", "Bo", "Cy", "Di"];
        for (id, name) in ids.iter().zip(names) {
            store
                .upsert_guest(&format!("tok-{id}"), *id, name)
                .await
                .expect("guest");
        }
        let code = format!("T{}", &ids[0].simple().to_string()[..5].to_uppercase());
        let match_id = Uuid::new_v4();
        let seats: [(Uuid, String); 4] =
            std::array::from_fn(|index| (ids[index], names[index].into()));
        let state = serde_json::json!({"phase": "arranging"});
        store
            .upsert_match(
                match_id,
                &state,
                &MatchWrite {
                    phase: "arranging".into(),
                    length: "one_deal".into(),
                    totals: [1, 2, 3, 4],
                    finished: false,
                    seats: seats.clone(),
                },
            )
            .await
            .expect("match");
        store
            .upsert_room(&RoomWrite {
                code: code.clone(),
                host: ids[0],
                length: "one_deal".into(),
                match_id: Some(match_id),
                updated_ms: 0,
                seats: seats
                    .iter()
                    .map(|(id, name)| Some((*id, name.clone())))
                    .collect(),
            })
            .await
            .expect("room");

        let loaded = store.load_active_matches().await.expect("load");
        assert!(loaded.iter().any(|(id, body)| {
            *id == match_id && body.get("phase").and_then(|v| v.as_str()) == Some("arranging")
        }));
        let rooms = store.load_rooms().await.expect("rooms");
        assert!(rooms
            .iter()
            .any(|room| room.code == code && room.match_id == Some(match_id)));

        store
            .upsert_match(
                match_id,
                &serde_json::json!({"phase": "summary"}),
                &MatchWrite {
                    phase: "summary".into(),
                    length: "one_deal".into(),
                    totals: [10, 0, 0, 0],
                    finished: true,
                    seats,
                },
            )
            .await
            .expect("finish");
        let loaded = store.load_active_matches().await.expect("load finished");
        assert!(loaded.iter().all(|(id, _)| *id != match_id));

        sqlx::query("DELETE FROM matches WHERE match_id = $1")
            .bind(match_id)
            .execute(&store.pool)
            .await
            .expect("delete match");
        sqlx::query("DELETE FROM rooms WHERE code = $1")
            .bind(&code)
            .execute(&store.pool)
            .await
            .expect("delete room");
        for id in ids {
            sqlx::query("DELETE FROM guest_sessions WHERE session_id = $1")
                .bind(id)
                .execute(&store.pool)
                .await
                .expect("delete guest");
        }
    }
}
