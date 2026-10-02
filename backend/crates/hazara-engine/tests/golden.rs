//! Golden fixture tests.
//!
//! A deterministic 52-card deal (one suit per player) that must produce
//! exactly the expected output from the engine. Both the Rust engine and the
//! Dart classifier must agree on these inputs.
//!
//! Suit-per-player ensures no duplicates and a clean 360-point total.

use std::collections::HashSet;

use hazara_domain::{Card, Rank, Suit};
use hazara_engine::{compare_combo, evaluate_set, play_deal, ComboKind};

fn c(suit: Suit, rank: Rank) -> Card {
    Card::new(suit, rank)
}

/// Four deterministic arrangements: [player][set_index].
/// - P0 → all Spades
/// - P1 → all Hearts
/// - P2 → all Diamonds
/// - P3 → all Clubs
///
/// Each player arranges their 13 same-suit cards strongest-first:
///   s0 (3): A K Q  → Colour Run (highest A → key 15)
///   s1 (3): J 10 9 → Colour Run (highest J → key 11)
///   s2 (3): 8 7 6  → Colour Run (highest 8)
///   s3 (4): 5 4 3 2 → engine picks 5 4 3 (Colour Run), spare = 2
fn golden() -> [[Vec<Card>; 4]; 4] {
    let p0 = [
        vec![
            c(Suit::Spades, Rank::Ace),
            c(Suit::Spades, Rank::King),
            c(Suit::Spades, Rank::Queen),
        ],
        vec![
            c(Suit::Spades, Rank::Jack),
            c(Suit::Spades, Rank::Ten),
            c(Suit::Spades, Rank::Nine),
        ],
        vec![
            c(Suit::Spades, Rank::Eight),
            c(Suit::Spades, Rank::Seven),
            c(Suit::Spades, Rank::Six),
        ],
        vec![
            c(Suit::Spades, Rank::Five),
            c(Suit::Spades, Rank::Four),
            c(Suit::Spades, Rank::Three),
            c(Suit::Spades, Rank::Two),
        ],
    ];
    let p1 = [
        vec![
            c(Suit::Hearts, Rank::Ace),
            c(Suit::Hearts, Rank::King),
            c(Suit::Hearts, Rank::Queen),
        ],
        vec![
            c(Suit::Hearts, Rank::Jack),
            c(Suit::Hearts, Rank::Ten),
            c(Suit::Hearts, Rank::Nine),
        ],
        vec![
            c(Suit::Hearts, Rank::Eight),
            c(Suit::Hearts, Rank::Seven),
            c(Suit::Hearts, Rank::Six),
        ],
        vec![
            c(Suit::Hearts, Rank::Five),
            c(Suit::Hearts, Rank::Four),
            c(Suit::Hearts, Rank::Three),
            c(Suit::Hearts, Rank::Two),
        ],
    ];
    let p2 = [
        vec![
            c(Suit::Diamonds, Rank::Ace),
            c(Suit::Diamonds, Rank::King),
            c(Suit::Diamonds, Rank::Queen),
        ],
        vec![
            c(Suit::Diamonds, Rank::Jack),
            c(Suit::Diamonds, Rank::Ten),
            c(Suit::Diamonds, Rank::Nine),
        ],
        vec![
            c(Suit::Diamonds, Rank::Eight),
            c(Suit::Diamonds, Rank::Seven),
            c(Suit::Diamonds, Rank::Six),
        ],
        vec![
            c(Suit::Diamonds, Rank::Five),
            c(Suit::Diamonds, Rank::Four),
            c(Suit::Diamonds, Rank::Three),
            c(Suit::Diamonds, Rank::Two),
        ],
    ];
    let p3 = [
        vec![
            c(Suit::Clubs, Rank::Ace),
            c(Suit::Clubs, Rank::King),
            c(Suit::Clubs, Rank::Queen),
        ],
        vec![
            c(Suit::Clubs, Rank::Jack),
            c(Suit::Clubs, Rank::Ten),
            c(Suit::Clubs, Rank::Nine),
        ],
        vec![
            c(Suit::Clubs, Rank::Eight),
            c(Suit::Clubs, Rank::Seven),
            c(Suit::Clubs, Rank::Six),
        ],
        vec![
            c(Suit::Clubs, Rank::Five),
            c(Suit::Clubs, Rank::Four),
            c(Suit::Clubs, Rank::Three),
            c(Suit::Clubs, Rank::Two),
        ],
    ];
    [p0, p1, p2, p3]
}

// ─────────────────────────────────────────────────────────────────────────────
// Fixture validity
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn golden_is_valid_52_card_partition() {
    let arr = golden();
    let mut seen = HashSet::new();
    for player in &arr {
        for set in player {
            for card in set {
                assert!(seen.insert(card.id()), "duplicate card: {}", card.id());
            }
        }
    }
    assert_eq!(seen.len(), 52);
}

// ─────────────────────────────────────────────────────────────────────────────
// Classifier golden tests
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn golden_set0_is_colour_run_ace_high() {
    let arr = golden();
    for player in &arr {
        let combo = evaluate_set(&player[0]).unwrap();
        assert_eq!(
            combo.kind,
            ComboKind::ColourRun,
            "set0 should be ColourRun: {}",
            combo.label
        );
        assert!(
            combo.label.contains('A'),
            "set0 label should mention A: {}",
            combo.label
        );
    }
}

#[test]
fn golden_set1_is_colour_run_jack_high() {
    let arr = golden();
    for player in &arr {
        let combo = evaluate_set(&player[1]).unwrap();
        assert_eq!(
            combo.kind,
            ComboKind::ColourRun,
            "set1 should be ColourRun: {}",
            combo.label
        );
        assert!(
            combo.label.contains('J'),
            "set1 label should mention J: {}",
            combo.label
        );
    }
}

#[test]
fn golden_set2_is_colour_run_eight_high() {
    let arr = golden();
    for player in &arr {
        let combo = evaluate_set(&player[2]).unwrap();
        assert_eq!(
            combo.kind,
            ComboKind::ColourRun,
            "set2 should be ColourRun: {}",
            combo.label
        );
    }
}

#[test]
fn golden_set3_spare_picks_best_three_and_leaves_a_spare() {
    let arr = golden();
    for player in &arr {
        let combo = evaluate_set(&player[3]).unwrap();
        // 5 4 3 2 → best trio = 5 4 3 (ColourRun), spare = 2
        assert_eq!(
            combo.kind,
            ComboKind::ColourRun,
            "spare set should be ColourRun: {}",
            combo.label
        );
        assert!(combo.spare.is_some(), "spare card should be present");
        assert_eq!(
            combo.spare.unwrap().rank,
            Rank::Two,
            "spare card should be the Two"
        );
    }
}

#[test]
fn golden_set0_beats_set1() {
    let arr = golden();
    let s0 = evaluate_set(&arr[0][0]).unwrap();
    let s1 = evaluate_set(&arr[0][1]).unwrap();
    assert!(
        compare_combo(&s0, &s1) > 0,
        "A-K-Q ColourRun must beat J-10-9 ColourRun"
    );
}

#[test]
fn golden_same_suit_arrangement_is_weakly_descending() {
    let arr = golden();
    for player in &arr {
        let s0 = evaluate_set(&player[0]).unwrap();
        let s1 = evaluate_set(&player[1]).unwrap();
        let s2 = evaluate_set(&player[2]).unwrap();
        assert!(compare_combo(&s0, &s1) >= 0, "s0 ≥ s1");
        assert!(compare_combo(&s1, &s2) >= 0, "s1 ≥ s2");
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Deal-level golden tests
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn golden_deal_total_is_360() {
    let arr = golden();
    let result = play_deal(&arr, 0);
    let total: u16 = result.beats.iter().map(|b| b.points).sum();
    assert_eq!(total, 360, "all beats must total exactly 360 points");
}

#[test]
fn golden_scores_sum_to_360() {
    let arr = golden();
    let result = play_deal(&arr, 0);
    let sum: u16 = result.scores.iter().sum();
    assert_eq!(sum, 360);
}

#[test]
fn golden_scores_are_deterministic() {
    let arr = golden();
    let r1 = play_deal(&arr, 0);
    let r2 = play_deal(&arr, 0);
    assert_eq!(r1.scores, r2.scores);
}

#[test]
fn golden_all_beats_have_tied_sets() {
    // Every beat is four equal ColourRuns — all tied.
    let arr = golden();
    let result = play_deal(&arr, 0);
    for beat in &result.beats {
        assert!(beat.tied, "beats should be tied when all hands are equal");
    }
}

#[test]
fn golden_each_beat_has_four_hands() {
    let arr = golden();
    let result = play_deal(&arr, 0);
    assert_eq!(result.beats.len(), 4);
    for beat in &result.beats {
        assert_eq!(beat.hands.len(), 4);
    }
}
