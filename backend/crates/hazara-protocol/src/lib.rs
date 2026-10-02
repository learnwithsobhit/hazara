//! Wire types shared by the HAZARA server and clients.
//!
//! Keep this crate free of I/O. Bump [`PROTOCOL_VERSION`] only with a
//! documented migration — the Flutter client refuses unknown protocols.

use serde::{Deserialize, Serialize};

/// Snapshot protocol the current Flutter client understands.
pub const PROTOCOL_VERSION: u32 = 1;

/// Inbound WebSocket frames larger than this are dropped by the server.
pub const MAX_WS_MESSAGE_BYTES: usize = 64 * 1024;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RoomPreview {
    pub host_name: String,
    pub seats_taken: u8,
    pub seats_total: u8,
    pub match_length: String,
    pub in_progress: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ClientMessage {
    Ping,
    Pong,
    SaveDraft { sets: Vec<Vec<String>> },
    Ready {
        action_id: String,
        sets: Vec<Vec<String>>,
    },
    NextDeal { summary_id: Option<u64> },
    Rematch,
    ForceEnd,
    Reaction { emoji: String },
    TalkText { text: String },
    Sound { sound: String },
    Voice {
        mime: String,
        duration_ms: u64,
        audio_b64: String,
    },
    Nudge { name: Option<String> },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ServerMessage {
    Pong,
    Ping,
    Snapshot { snapshot: serde_json::Value },
    Error { message: String },
    Talk {
        kind: String,
        from: String,
        #[serde(default)]
        seat: Option<u8>,
        #[serde(flatten)]
        extra: serde_json::Value,
    },
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn client_ready_round_trips() {
        let msg = ClientMessage::Ready {
            action_id: "a1".into(),
            sets: vec![vec!["hearts-ace".into()]],
        };
        let json = serde_json::to_string(&msg).unwrap();
        assert!(json.contains("\"type\":\"ready\""));
        let back: ClientMessage = serde_json::from_str(&json).unwrap();
        assert_eq!(back, msg);
    }

    #[test]
    fn protocol_is_v1() {
        assert_eq!(PROTOCOL_VERSION, 1);
        assert_eq!(MAX_WS_MESSAGE_BYTES, 64 * 1024);
    }
}
