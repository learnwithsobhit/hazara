# File state before Postgres

The friends table writes one JSON document before it acknowledges a move. A restart reads that file and restores the phase, the hand, and the scores.

Postgres is the later store. This file is local only. It holds private cards, so it stays out of git and out of logs. Railway stays at one replica until a match has an ownership epoch that can reject a stale writer.
