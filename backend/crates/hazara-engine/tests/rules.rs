use hazara_domain::{Card, Rank, Suit};
use hazara_engine::{
    compare_combo, deck_points, deterministic_legal, evaluate_set, play_deal, standard_deck,
    validate_arrangement, ArrangeError, ComboKind,
};

fn c(suit: Suit, rank: Rank) -> Card {
    Card::new(suit, rank)
}

#[test]
fn full_deck_is_worth_360() {
    assert_eq!(deck_points(), 360);
}

#[test]
fn troy_beats_a_colour_run() {
    let troy = evaluate_set(&[
        c(Suit::Hearts, Rank::Ace),
        c(Suit::Diamonds, Rank::Ace),
        c(Suit::Clubs, Rank::Ace),
    ])
    .unwrap();
    let colour_run = evaluate_set(&[
        c(Suit::Spades, Rank::Ace),
        c(Suit::Spades, Rank::King),
        c(Suit::Spades, Rank::Queen),
    ])
    .unwrap();
    assert_eq!(troy.kind, ComboKind::Troy);
    assert_eq!(troy.label, "Troy of Aces");
    assert!(compare_combo(&troy, &colour_run) > 0);
}

#[test]
fn colour_runs_rank_ace_king_queen_then_ace_two_three_then_king_queen_jack() {
    let akq = evaluate_set(&[
        c(Suit::Spades, Rank::Ace),
        c(Suit::Spades, Rank::King),
        c(Suit::Spades, Rank::Queen),
    ])
    .unwrap();
    let a23 = evaluate_set(&[
        c(Suit::Hearts, Rank::Ace),
        c(Suit::Hearts, Rank::Two),
        c(Suit::Hearts, Rank::Three),
    ])
    .unwrap();
    let kqj = evaluate_set(&[
        c(Suit::Diamonds, Rank::King),
        c(Suit::Diamonds, Rank::Queen),
        c(Suit::Diamonds, Rank::Jack),
    ])
    .unwrap();
    assert_eq!(akq.label, "Colour Run: A\u{2013}K\u{2013}Q");
    assert_eq!(a23.label, "Colour Run: A\u{2013}2\u{2013}3");
    assert!(compare_combo(&akq, &a23) > 0);
    assert!(compare_combo(&a23, &kqj) > 0);
}

#[test]
fn two_ace_king_of_one_suit_is_colour() {
    let around = evaluate_set(&[
        c(Suit::Spades, Rank::Two),
        c(Suit::Spades, Rank::Ace),
        c(Suit::Spades, Rank::King),
    ])
    .unwrap();
    let ak3 = evaluate_set(&[
        c(Suit::Hearts, Rank::Ace),
        c(Suit::Hearts, Rank::King),
        c(Suit::Hearts, Rank::Three),
    ])
    .unwrap();
    let aqj = evaluate_set(&[
        c(Suit::Diamonds, Rank::Ace),
        c(Suit::Diamonds, Rank::Queen),
        c(Suit::Diamonds, Rank::Jack),
    ])
    .unwrap();
    assert_eq!(around.kind, ComboKind::Colour);
    assert!(around.label.starts_with("Colour:"));
    assert!(compare_combo(&ak3, &around) > 0);
    assert!(compare_combo(&around, &aqj) > 0);
}

#[test]
fn equal_runs_compare_equal() {
    let left = evaluate_set(&[
        c(Suit::Hearts, Rank::Seven),
        c(Suit::Clubs, Rank::Six),
        c(Suit::Diamonds, Rank::Five),
    ])
    .unwrap();
    let right = evaluate_set(&[
        c(Suit::Spades, Rank::Seven),
        c(Suit::Diamonds, Rank::Six),
        c(Suit::Clubs, Rank::Five),
    ])
    .unwrap();
    assert_eq!(left.kind, ComboKind::Run);
    assert_eq!(compare_combo(&left, &right), 0);
}

#[test]
fn colour_compares_the_second_card() {
    let higher = evaluate_set(&[
        c(Suit::Hearts, Rank::Jack),
        c(Suit::Hearts, Rank::Nine),
        c(Suit::Hearts, Rank::Two),
    ])
    .unwrap();
    let lower = evaluate_set(&[
        c(Suit::Spades, Rank::Jack),
        c(Suit::Spades, Rank::Eight),
        c(Suit::Spades, Rank::Seven),
    ])
    .unwrap();
    assert_eq!(higher.kind, ComboKind::Colour);
    assert!(compare_combo(&higher, &lower) > 0);
}

#[test]
fn spare_card_is_left_out_of_the_best_trio() {
    let combo = evaluate_set(&[
        c(Suit::Hearts, Rank::Seven),
        c(Suit::Diamonds, Rank::Seven),
        c(Suit::Clubs, Rank::Four),
        c(Suit::Spades, Rank::Two),
    ])
    .unwrap();
    assert_eq!(combo.label, "Pair of Sevens");
    assert_eq!(combo.spare, Some(c(Suit::Spades, Rank::Two)));
}

#[test]
fn ready_rejects_a_stronger_lower_set() {
    let sets = [
        vec![
            c(Suit::Hearts, Rank::Ten),
            c(Suit::Diamonds, Rank::Nine),
            c(Suit::Clubs, Rank::Eight),
        ],
        vec![
            c(Suit::Hearts, Rank::Ace),
            c(Suit::Diamonds, Rank::Ace),
            c(Suit::Clubs, Rank::Ace),
        ],
        vec![
            c(Suit::Spades, Rank::King),
            c(Suit::Spades, Rank::Queen),
            c(Suit::Spades, Rank::Jack),
        ],
        vec![
            c(Suit::Hearts, Rank::Seven),
            c(Suit::Diamonds, Rank::Seven),
            c(Suit::Clubs, Rank::Four),
            c(Suit::Spades, Rank::Two),
        ],
    ];
    assert_eq!(
        validate_arrangement(&sets),
        Err(ArrangeError::NotDescending)
    );
}

#[test]
fn deadline_lock_is_legal_and_stable() {
    let deck = standard_deck();
    for start in (0..52).step_by(13) {
        let hand: Vec<Card> = (0..13).map(|offset| deck[(start + offset) % 52]).collect();
        let first = deterministic_legal(&hand).unwrap();
        let second = deterministic_legal(&hand).unwrap();
        assert_eq!(first, second);
        validate_arrangement(&first).unwrap();
        let mut dealt: Vec<Card> = first.iter().flatten().copied().collect();
        let mut original = hand.clone();
        dealt.sort_by_key(|a| a.id());
        original.sort_by_key(|a| a.id());
        assert_eq!(dealt, original);
    }
}

#[test]
fn later_player_wins_an_equal_run() {
    // Pagat: A–Q–9 colour, 7–6–5 run, K–K–J pair, 7–6–5 run.
    // The two runs are equal, so the later one wins.
    let arrangements = [
        colour_hand(),
        run_hand(Suit::Hearts, Suit::Clubs, Suit::Diamonds),
        pair_hand(),
        run_hand(Suit::Spades, Suit::Diamonds, Suit::Clubs),
    ];
    let result = play_deal(&arrangements, 3);
    assert_eq!(result.beats[0].order, [0, 1, 2, 3]);
    assert_eq!(result.beats[0].winner, 3);
    assert!(result.beats[0].tied);
}

#[test]
fn a_deal_conserves_52_cards_and_360_points() {
    let deck = standard_deck();
    let mut arrangements: [[Vec<Card>; 4]; 4] = Default::default();
    for seat in 0..4 {
        let hand: Vec<Card> = deck[seat * 13..(seat + 1) * 13].to_vec();
        arrangements[seat] = deterministic_legal(&hand).unwrap();
    }
    let result = play_deal(&arrangements, 0);
    assert_eq!(result.beats[0].leader, 1);
    let captured: u16 = result.beats.iter().map(|beat| beat.points).sum();
    assert_eq!(captured, 360);
    assert_eq!(result.scores.iter().sum::<u16>(), 360);
    let cards: usize = arrangements.iter().flatten().map(|set| set.len()).sum();
    assert_eq!(cards, 52);
}

fn colour_hand() -> [Vec<Card>; 4] {
    [
        vec![
            c(Suit::Spades, Rank::Ace),
            c(Suit::Spades, Rank::Queen),
            c(Suit::Spades, Rank::Nine),
        ],
        vec![
            c(Suit::Hearts, Rank::Four),
            c(Suit::Clubs, Rank::Three),
            c(Suit::Diamonds, Rank::Two),
        ],
        vec![
            c(Suit::Hearts, Rank::Three),
            c(Suit::Clubs, Rank::Two),
            c(Suit::Diamonds, Rank::Ace),
        ],
        filler_spare(),
    ]
}

fn run_hand(seven: Suit, six: Suit, five: Suit) -> [Vec<Card>; 4] {
    [
        vec![
            c(seven, Rank::Seven),
            c(six, Rank::Six),
            c(five, Rank::Five),
        ],
        vec![
            c(Suit::Hearts, Rank::Nine),
            c(Suit::Clubs, Rank::Eight),
            c(Suit::Diamonds, Rank::Four),
        ],
        vec![
            c(Suit::Spades, Rank::Four),
            c(Suit::Hearts, Rank::Three),
            c(Suit::Clubs, Rank::Two),
        ],
        filler_spare(),
    ]
}

fn pair_hand() -> [Vec<Card>; 4] {
    [
        vec![
            c(Suit::Hearts, Rank::King),
            c(Suit::Diamonds, Rank::King),
            c(Suit::Clubs, Rank::Jack),
        ],
        vec![
            c(Suit::Spades, Rank::Eight),
            c(Suit::Hearts, Rank::Five),
            c(Suit::Clubs, Rank::Four),
        ],
        vec![
            c(Suit::Diamonds, Rank::Three),
            c(Suit::Hearts, Rank::Two),
            c(Suit::Spades, Rank::Three),
        ],
        filler_spare(),
    ]
}

fn filler_spare() -> Vec<Card> {
    vec![
        c(Suit::Clubs, Rank::Nine),
        c(Suit::Diamonds, Rank::Eight),
        c(Suit::Hearts, Rank::Eight),
        c(Suit::Spades, Rank::Two),
    ]
}
