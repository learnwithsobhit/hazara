# HAZARA architecture

Flutter web talks to one local Axum process. A later deploy is Railway for the API and Firebase Hosting for the web app. This repository does not deploy yet.

One Tokio task owns each live match. `hazara-engine` is pure: it ranks combinations, checks a descending hand, and scores a deal. The server shuffles outside the engine.

The process writes one compact JSON file per match (`hazara-data/{uuid}.match`) before accepting a move, then restores those files on boot. Guest sessions and lobby rooms are written to `hazara-data/guests.json` and `hazara-data/rooms.json`. All files hold private cards and must never be committed. Draft saves (tapping a card into a set) are debounced to a single write per 300 ms window; ready/next-deal writes are immediate. PostgreSQL is the later store. Railway stays at one replica until a match has an ownership epoch.

The bind address is `HAZARA_BIND` (or the Railway-injected `PORT` variable). The default is `127.0.0.1:8080`. Graceful shutdown is on `SIGTERM` and `SIGINT`. A background task reaps empty lobby rooms after 2 hours and orphaned match files after 24 hours.

Each socket sees only that seat’s cards. Other hands stay on the server until a set is revealed. Reveal order is the rules order, with a dwell of 4.5 seconds for the first three sets and 6 seconds for the spare set. The client clock is corrected with `server_now`.

Protocol version is 1. A different version shows “Update HAZARA to keep playing” and does not open the table.
