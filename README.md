# HAZARA

Four-player card game. This repository is separate from Judgement.

**Local friends table:** four people join a room code on this computer. The server writes the deal to `backend/hazara-data/state.json` before it accepts a move. Restarting the server restores the same phase and the same hand. That file contains private cards. Do not commit it, and do not print it. There is no public queue, no ratings, and no computer player. Do not deploy from this step.

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
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 7357
```

Open http://127.0.0.1:7357 in four browser windows. Each person enters a name, one creates a table, the others join the code. A link of the form `http://127.0.0.1:7357/?room=CODE` fills the code. Start stays off until four people are seated, and the button says how many are still needed. Refreshing the page keeps the name. **Return to your table** opens the same seat after the server is restarted.

After all four hands lock, the table shows one set at a time (about 4.5 seconds, 6 seconds for the spare set), then the deal summary. The summary includes a 360-point check. The host starts the next deal when ready.

“Try the cards on this device” still arranges a sample hand with no server. **Play online** stays visible and off.

The useful width is a phone column (max 480px), centered on a wide window. Railway and Firebase files are present for a later deploy. This step does not deploy.
