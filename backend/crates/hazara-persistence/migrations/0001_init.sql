-- Guest-first lobby plus one tip snapshot per match.
-- `matches.state` is a SavedTable and contains private cards. Do not log it.

CREATE TABLE guest_sessions (
    session_id  UUID PRIMARY KEY,
    token       TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    avatar_id   TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE rooms (
    code              TEXT PRIMARY KEY,
    host_session_id   UUID NOT NULL REFERENCES guest_sessions (session_id),
    match_length      TEXT NOT NULL,
    match_id          UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE room_seats (
    code        TEXT NOT NULL REFERENCES rooms (code) ON DELETE CASCADE,
    seat        SMALLINT NOT NULL CHECK (seat BETWEEN 0 AND 3),
    player_id   UUID NOT NULL REFERENCES guest_sessions (session_id),
    name        TEXT NOT NULL,
    PRIMARY KEY (code, seat),
    UNIQUE (code, player_id)
);

CREATE TABLE matches (
    match_id       UUID PRIMARY KEY,
    room_code      TEXT REFERENCES rooms (code) ON DELETE SET NULL,
    status         TEXT NOT NULL CHECK (status IN ('active', 'finished')),
    phase          TEXT NOT NULL,
    length         TEXT NOT NULL,
    state_version  BIGINT NOT NULL DEFAULT 0,
    state          JSONB NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at    TIMESTAMPTZ
);

CREATE TABLE match_players (
    match_id    UUID NOT NULL REFERENCES matches (match_id) ON DELETE CASCADE,
    player_id   UUID NOT NULL REFERENCES guest_sessions (session_id),
    name        TEXT NOT NULL,
    seat        SMALLINT NOT NULL CHECK (seat BETWEEN 0 AND 3),
    PRIMARY KEY (match_id, seat),
    UNIQUE (match_id, player_id)
);

CREATE TABLE match_results (
    match_id     UUID PRIMARY KEY REFERENCES matches (match_id) ON DELETE CASCADE,
    totals       JSONB NOT NULL,
    finished_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX matches_active_idx ON matches (status) WHERE status = 'active';
CREATE INDEX matches_room_idx ON matches (room_code);
