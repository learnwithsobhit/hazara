//! Live table talk. These messages are broadcast and then forgotten.
//! They are never written to the match file.

pub const MAX_TEXT_LEN: usize = 40;
const WORD_GAP_MS: u64 = 800;
const AUDIO_GAP_MS: u64 = 6_000;
pub const MAX_VOICE_MS: u64 = 6_000;
const MIN_VOICE_MS: u64 = 400;
const MAX_VOICE_B64: usize = 40_000;

const EMOJIS: &[&str] = &[
    "🔥", "😂", "👏", "😱", "😎", "💀", "🎯", "🙌", "😤", "👀", "💪", "✨", "🃏", "👑", "💚", "😅",
    "♠️", "♥️",
];

const SOUNDS: &[&str] = &[
    "laugh", "clap", "oh_no", "nice", "gg", "airhorn", "facepalm",
];

const VOICE_MIMES: &[&str] = &[
    "audio/webm",
    "audio/webm;codecs=opus",
    "audio/ogg",
    "audio/ogg;codecs=opus",
];

pub struct Pace {
    pub words_at: u64,
    pub audio_at: u64,
}

impl Pace {
    pub fn fresh() -> Self {
        Self {
            words_at: 0,
            audio_at: 0,
        }
    }

    pub fn allow_words(&mut self, now: u64) -> bool {
        if now.saturating_sub(self.words_at) < WORD_GAP_MS {
            return false;
        }
        self.words_at = now;
        true
    }

    pub fn allow_audio(&mut self, now: u64) -> bool {
        if now.saturating_sub(self.audio_at) < AUDIO_GAP_MS {
            return false;
        }
        self.audio_at = now;
        true
    }

    pub fn refund_audio(&mut self) {
        self.audio_at = 0;
    }
}

pub fn is_emoji(emoji: &str) -> bool {
    EMOJIS.contains(&emoji)
}

pub fn is_sound(id: &str) -> bool {
    SOUNDS.contains(&id)
}

pub fn style_text(text: &str) -> Vec<&'static str> {
    let normalized = text.trim().to_lowercase();
    const LEX: &[(&str, &[&str])] = &[
        ("zabardast", &["💪", "✨"]),
        ("come on", &["💪", "😤"]),
        ("lets go", &["🔥", "💪"]),
        ("let's go", &["🔥", "💪"]),
        ("oh no", &["😱", "💀"]),
        ("unlucky", &["💀"]),
        ("hazara", &["🃏", "✨"]),
        ("clutch", &["👏", "🔥"]),
        ("troy", &["👑", "✨"]),
        ("solid", &["💪", "✨"]),
        ("arey", &["😱"]),
        ("arre", &["😱"]),
        ("nice", &["👏", "🔥"]),
        ("oops", &["😱"]),
        ("haha", &["😂"]),
        ("lmao", &["😂", "💀"]),
        ("lol", &["😂"]),
        ("wow", &["😱", "✨"]),
        ("good", &["👏"]),
        ("fire", &["🔥"]),
        ("cool", &["😎"]),
        ("gg", &["🙌", "✨"]),
        ("set", &["🃏"]),
    ];
    for (key, emojis) in LEX {
        if normalized.contains(key) {
            return emojis.to_vec();
        }
    }
    vec!["✨"]
}

pub fn validate_voice(mime: &str, duration_ms: u64, audio_b64: &str) -> Result<(), &'static str> {
    let mime = mime.trim().to_ascii_lowercase();
    if !VOICE_MIMES.iter().any(|allowed| mime == *allowed) {
        return Err("That voice note could not be played.");
    }
    if !(MIN_VOICE_MS..=MAX_VOICE_MS).contains(&duration_ms) {
        return Err("Keep the voice note under 6 seconds.");
    }
    if audio_b64.len() > MAX_VOICE_B64 || audio_b64.is_empty() {
        return Err("That voice note is too long.");
    }
    if !audio_b64
        .bytes()
        .all(|byte| matches!(byte, b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'+' | b'/' | b'='))
    {
        return Err("That voice note could not be played.");
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn troy_text_picks_a_crown() {
        assert!(style_text("what a troy").contains(&"👑"));
    }

    #[test]
    fn unknown_emoji_is_refused() {
        assert!(!is_emoji("nope"));
        assert!(is_emoji("🃏"));
    }

    #[test]
    fn voice_rejects_a_long_clip() {
        assert!(validate_voice("audio/webm", 9_000, "AAAA").is_err());
        assert!(validate_voice("audio/webm", 1_000, "AAAA").is_ok());
    }

    #[test]
    fn words_wait_a_moment_between_sends() {
        let mut pace = Pace::fresh();
        assert!(pace.allow_words(1_000));
        assert!(!pace.allow_words(1_200));
        assert!(pace.allow_words(1_900));
    }
}
