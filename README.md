# HAZARA

Four-player Pagat Hazari. This repository is separate from Judgement.

**Friends table:** four people join a room code. Before it accepts a move, the server writes the deal to Postgres when `DATABASE_URL` is set, or under `HAZARA_STATE` (default `backend/hazara-data/`) otherwise. Restarting the server restores active matches. Those records contain private cards. Do not commit them, and do not print them. There is no public queue, no ratings, and no computer player.

## Rules engine

```bash
cd backend
cargo test
```

`hazara-engine` is pure Rust: combination rank, the spare-card trio, descending sets, a deterministic legal lock, and reveal order. A faster packet cannot change who wins a tie.

## Run a friends table on this computer

Terminal 1:

```bash
cd backend
cargo run -p hazara-server
```

That listens on http://127.0.0.1:8080

Terminal 2:

```bash
cd frontend/hazara_flutter
flutter test
flutter run -d web-server --release --web-hostname 127.0.0.1 --web-port 7357 --no-web-resources-cdn
```

Open http://127.0.0.1:7357 in four browser windows. Each person enters a name, one creates a table, the others join the code. A link of the form `http://127.0.0.1:7357/?room=CODE` fills the code. Start stays off until four people are seated.

Release web is baked with `--dart-define=API_BASE=...`. Local debug defaults to `http://127.0.0.1:8080`.

## Deploy

Same split as Judgement: **Firebase Hosting** for Flutter web, **Railway** for `hazara-server`, **Railway Postgres** for guests, rooms, and match snapshots. One replica (a match has one in-process owner). Set `DATABASE_URL` from the Postgres plugin. `HAZARA_MIGRATIONS_DIR` is `/srv/migrations` in the image. Without `DATABASE_URL` the process still uses the `/data` volume.

```bash
# API (from repo root, after railway link)
railway up -s hazara-server

# Web
cd frontend/hazara_flutter
API_BASE=https://YOUR-RAILWAY-HOST \
PUBLIC_WEB_ORIGIN=https://hazara-lws-260731.web.app \
  ./tool/build_web_release.sh
firebase deploy --only hosting:prod --project judgment-lws-260731 --non-interactive
```

Set `HAZARA_CORS_ORIGIN` / `ALLOWED_ORIGINS` to the Firebase origins (no trailing slash). Env template: `deployment/railway.env.example`.
