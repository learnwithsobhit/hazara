use hazara_domain::{Card, Rank};

/// Strongest last, so a higher discriminant wins. Matches the Flutter enum order.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum ComboKind {
    Indi,
    Pair,
    Colour,
    Run,
    ColourRun,
    Troy,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Combo {
    pub kind: ComboKind,
    pub key: Vec<u8>,
    pub label: String,
    pub counting: Vec<Card>,
    pub spare: Option<Card>,
}

/// Positive when `a` is stronger than `b`. Zero when they are equal.
pub fn compare_combo(a: &Combo, b: &Combo) -> i32 {
    let kind_order = (a.kind as i32) - (b.kind as i32);
    if kind_order != 0 {
        return kind_order;
    }
    let length = a.key.len().min(b.key.len());
    for i in 0..length {
        let key_order = i32::from(a.key[i]) - i32::from(b.key[i]);
        if key_order != 0 {
            return key_order;
        }
    }
    a.key.len() as i32 - b.key.len() as i32
}

pub fn evaluate_set(cards: &[Card]) -> Option<Combo> {
    if cards.len() < 3 {
        return None;
    }
    if cards.len() == 3 {
        return Some(classify(cards));
    }
    Some(best_of_four(cards))
}

fn best_of_four(cards: &[Card]) -> Combo {
    let mut best: Option<Combo> = None;
    let mut best_tie: Option<String> = None;
    for subset in subsets_of_three(cards) {
        let combo = classify(&subset);
        let tie = tie_id(&subset);
        let replaces = match &best {
            None => true,
            Some(current) => {
                let order = compare_combo(&combo, current);
                order > 0 || (order == 0 && tie < *best_tie.as_ref().unwrap())
            }
        };
        if replaces {
            best = Some(combo);
            best_tie = Some(tie);
        }
    }
    let chosen = best.expect("four cards always contain a trio");
    let spare = cards
        .iter()
        .copied()
        .find(|card| !chosen.counting.contains(card))
        .expect("one card is left out of the trio");
    Combo {
        kind: chosen.kind,
        key: chosen.key,
        label: chosen.label,
        counting: chosen.counting,
        spare: Some(spare),
    }
}

fn classify(cards: &[Card]) -> Combo {
    let run = run_key(cards);
    let suited = cards.iter().all(|card| card.suit == cards[0].suit);
    if let Some(key) = run {
        if suited {
            return Combo {
                kind: ComboKind::ColourRun,
                key: vec![key],
                label: format!("Colour Run: {}", run_label(cards)),
                counting: cards.to_vec(),
                spare: None,
            };
        }
        return Combo {
            kind: ComboKind::Run,
            key: vec![key],
            label: format!("Run: {}", run_label(cards)),
            counting: cards.to_vec(),
            spare: None,
        };
    }
    let mut counts = [0u8; 13];
    for card in cards {
        counts[card.rank as usize] += 1;
    }
    let distinct = counts.iter().filter(|count| **count > 0).count();
    if distinct == 1 {
        return Combo {
            kind: ComboKind::Troy,
            key: vec![cards[0].rank.ace_high()],
            label: format!("Troy of {}", cards[0].rank.plural()),
            counting: cards.to_vec(),
            spare: None,
        };
    }
    if suited {
        let ordered = high_to_low(cards);
        return Combo {
            kind: ComboKind::Colour,
            key: ordered.iter().map(|card| card.rank.ace_high()).collect(),
            label: format!("Colour: {}", joined(&ordered)),
            counting: cards.to_vec(),
            spare: None,
        };
    }
    if distinct == 2 {
        let pair_rank = Rank::ALL
            .into_iter()
            .find(|rank| counts[*rank as usize] == 2)
            .expect("a pair has a doubled rank");
        let kicker = cards.iter().find(|card| card.rank != pair_rank).unwrap();
        let pair_card = cards.iter().find(|card| card.rank == pair_rank).unwrap();
        return Combo {
            kind: ComboKind::Pair,
            key: vec![pair_card.rank.ace_high(), kicker.rank.ace_high()],
            label: format!("Pair of {}", pair_card.rank.plural()),
            counting: cards.to_vec(),
            spare: None,
        };
    }
    let ordered = high_to_low(cards);
    Combo {
        kind: ComboKind::Indi,
        key: ordered.iter().map(|card| card.rank.ace_high()).collect(),
        label: format!("Indi: {}", joined(&ordered)),
        counting: cards.to_vec(),
        spare: None,
    }
}

/// A–K–Q is 15, A–2–3 is 14, K–Q–J is 13, down to 4–3–2 as 4.
fn run_key(cards: &[Card]) -> Option<u8> {
    let mut highs: Vec<u8> = cards.iter().map(|card| card.rank.ace_high()).collect();
    highs.sort_unstable();
    highs.dedup();
    if highs.len() != 3 {
        return None;
    }
    highs.sort_by(|a, b| b.cmp(a));
    if highs[0] == 14 && highs[1] == 3 && highs[2] == 2 {
        return Some(14);
    }
    let consecutive = highs[0] == highs[1] + 1 && highs[1] == highs[2] + 1;
    if !consecutive {
        return None;
    }
    if highs[0] == 14 {
        Some(15)
    } else {
        Some(highs[0])
    }
}

fn run_label(cards: &[Card]) -> String {
    let highs: Vec<u8> = cards.iter().map(|card| card.rank.ace_high()).collect();
    if highs.contains(&14) && highs.contains(&2) && highs.contains(&3) {
        let ace = cards.iter().find(|card| card.rank == Rank::Ace).unwrap();
        let two = cards.iter().find(|card| card.rank == Rank::Two).unwrap();
        let three = cards.iter().find(|card| card.rank == Rank::Three).unwrap();
        return format!(
            "{}\u{2013}{}\u{2013}{}",
            ace.rank.label(),
            two.rank.label(),
            three.rank.label()
        );
    }
    joined(&high_to_low(cards))
}

fn high_to_low(cards: &[Card]) -> Vec<Card> {
    let mut copy = cards.to_vec();
    copy.sort_by(|a, b| b.rank.ace_high().cmp(&a.rank.ace_high()));
    copy
}

fn joined(cards: &[Card]) -> String {
    cards
        .iter()
        .map(|card| card.rank.label())
        .collect::<Vec<_>>()
        .join("\u{2013}")
}

fn tie_id(cards: &[Card]) -> String {
    let mut ids: Vec<String> = cards.iter().map(|card| card.id()).collect();
    ids.sort();
    ids.join("|")
}

fn subsets_of_three(cards: &[Card]) -> Vec<Vec<Card>> {
    let mut subsets = Vec::new();
    for i in 0..cards.len() {
        for j in (i + 1)..cards.len() {
            for k in (j + 1)..cards.len() {
                subsets.push(vec![cards[i], cards[j], cards[k]]);
            }
        }
    }
    subsets
}
