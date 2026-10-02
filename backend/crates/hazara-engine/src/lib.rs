//! Pure HAZARA rules. No sockets, database, or clock.

mod arrange;
mod classify;
mod play;

pub use arrange::{deterministic_legal, validate_arrangement, ArrangeError};
pub use classify::{compare_combo, evaluate_set, Combo, ComboKind};
pub use hazara_domain::{deck_points, standard_deck, Card, Rank, Suit};
pub use play::{play_deal, Beat, DealResult};
