use hazara_domain::Card;

use crate::classify::{compare_combo, evaluate_set};

pub const SET_SIZES: [usize; 4] = [3, 3, 3, 4];

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ArrangeError {
    NotThirteen,
    DuplicateCard,
    WrongSize,
    NotDescending,
    NoLegal,
}

/// Sizes must be 3, 3, 3, 4, cards unique, and each set weakly at least as strong as the next.
pub fn validate_arrangement(sets: &[Vec<Card>; 4]) -> Result<(), ArrangeError> {
    let mut seen = Vec::with_capacity(13);
    for (index, set) in sets.iter().enumerate() {
        if set.len() != SET_SIZES[index] {
            return Err(ArrangeError::WrongSize);
        }
        for card in set {
            if seen.contains(card) {
                return Err(ArrangeError::DuplicateCard);
            }
            seen.push(*card);
        }
    }
    if seen.len() != 13 {
        return Err(ArrangeError::NotThirteen);
    }
    for index in 0..3 {
        let left = evaluate_set(&sets[index]).expect("set has three cards");
        let right = evaluate_set(&sets[index + 1]).expect("set has at least three cards");
        if compare_combo(&left, &right) < 0 {
            return Err(ArrangeError::NotDescending);
        }
    }
    Ok(())
}

/// First weakly descending 3/3/3/4 in card-id order.
/// This locks a legal hand. It does not search for a strong one.
pub fn deterministic_legal(cards: &[Card]) -> Result<[Vec<Card>; 4], ArrangeError> {
    if cards.len() != 13 {
        return Err(ArrangeError::NotThirteen);
    }
    let mut ordered = cards.to_vec();
    ordered.sort_by_key(|a| a.id());
    if ordered.windows(2).any(|pair| pair[0] == pair[1]) {
        return Err(ArrangeError::DuplicateCard);
    }

    let mut spare_idx = [0usize, 1, 2, 3];
    loop {
        let spare = pick(&ordered, &spare_idx);
        let rest = omit(&ordered, &spare_idx);
        if let Some(three) = first_three(&rest, &spare) {
            return Ok([three[0].clone(), three[1].clone(), three[2].clone(), spare]);
        }
        if !next_comb(&mut spare_idx, 13) {
            break;
        }
    }
    Err(ArrangeError::NoLegal)
}

fn first_three(rest: &[Card], spare: &[Card]) -> Option<[Vec<Card>; 3]> {
    let spare_combo = evaluate_set(spare)?;
    let mut group_a = [0usize, 1, 2];
    loop {
        let set0 = pick(rest, &group_a);
        let combo0 = evaluate_set(&set0)?;
        let mid = omit(rest, &group_a);
        let mut group_b = [0usize, 1, 2];
        loop {
            let set1 = pick(&mid, &group_b);
            let combo1 = evaluate_set(&set1)?;
            if compare_combo(&combo0, &combo1) >= 0 {
                let set2 = omit(&mid, &group_b);
                let combo2 = evaluate_set(&set2)?;
                if compare_combo(&combo1, &combo2) >= 0 && compare_combo(&combo2, &spare_combo) >= 0
                {
                    return Some([set0, set1, set2]);
                }
            }
            if !next_comb(&mut group_b, 6) {
                break;
            }
        }
        if !next_comb(&mut group_a, 9) {
            break;
        }
    }
    None
}

fn pick(cards: &[Card], indexes: &[usize]) -> Vec<Card> {
    indexes.iter().map(|index| cards[*index]).collect()
}

fn omit(cards: &[Card], indexes: &[usize]) -> Vec<Card> {
    cards
        .iter()
        .enumerate()
        .filter(|(index, _)| !indexes.contains(index))
        .map(|(_, card)| *card)
        .collect()
}

fn next_comb(comb: &mut [usize], n: usize) -> bool {
    let k = comb.len();
    let mut i = k;
    while i > 0 {
        i -= 1;
        if comb[i] < n - k + i {
            comb[i] += 1;
            for j in (i + 1)..k {
                comb[j] = comb[j - 1] + 1;
            }
            return true;
        }
    }
    false
}
