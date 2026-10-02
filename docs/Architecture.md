# HAZARA architecture

Flutter web talks to one Axum process. The API runs on Railway and the web app on Firebase Hosting.

One Tokio task owns each live match. `hazara-engine` is pure: it ranks combinations, checks a descending hand, and scores a deal. The server shuffles outside the engine.

The live table tells every seat about a move before that move is written. Ready status and the score step are not held for Postgres or the match file. A newer snapshot replaces one that is still waiting to be saved. When `DATABASE_URL` is set, guests, rooms, and the match snapshot live in Postgres (`hazara-persistence`). Otherwise they are files under `HAZARA_STATE` (default `hazara-data/`): `guests.json`, `rooms.json`, and `{uuid}.match`. Those files and the `matches.state` column hold private cards and must never be committed or logged. Draft saves are debounced to one write per 300 ms window; ready and next-deal writes are queued immediately. Railway stays at one replica until a match has an ownership epoch.

The bind address is `HAZARA_BIND` (or the Railway-injected `PORT` variable). The default is `127.0.0.1:8080`. Graceful shutdown is on `SIGTERM` and `SIGINT`. A background task reaps empty lobby rooms after 2 hours and finished matches after 24 hours. Migrations run from `HAZARA_MIGRATIONS_DIR` on boot when Postgres is configured.

Each socket sees only that seat’s cards. Other hands stay on the server until a set is revealed. Reveal order is the rules order, with a dwell of 12 seconds for the first three sets and 16 seconds for the spare set. During reveal the snapshot includes every set shown so far, so the running total survives a reconnect. The client clock is corrected with `server_now`.

Protocol version is 1. A different version shows “Update HAZARA to keep playing” and does not open the table.
