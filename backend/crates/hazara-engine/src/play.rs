use hazara_domain::Card;

use crate::classify::{compare_combo, evaluate_set, Combo};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Beat {
    pub leader: u8,
    pub order: [u8; 4],
    /// Index into `order` of the winning seat, also the seat number.
    pub winner: u8,
    pub points: u16,
    pub tied: bool,
    pub labels: [String; 4],
    /// Sets in play order. The fourth set may include a spare card.
    pub hands: [Vec<Card>; 4],
    pub spares: [Option<Card>; 4],
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DealResult {
    pub beats: [Beat; 4],
    pub scores: [u16; 4],
}

/// Each seat is four sets, strongest first. Seats run anticlockwise.
/// The first lead is the seat to the right of the dealer.
pub fn play_deal(arrangements: &[[Vec<Card>; 4]; 4], dealer: u8) -> DealResult {
    let mut leader = (dealer + 1) % 4;
    let mut scores = [0u16; 4];
    let mut beats = Vec::with_capacity(4);
    for (beat_index, _) in arrangements[0].iter().enumerate() {
        let groups: Vec<Combo> = (0..4)
            .map(|seat| evaluate_set(&arrangements[seat as usize][beat_index]).expect("sealed set"))
            .collect();
        let order = play_order(leader);
        let (winner, tied) = winner_in_order(&groups, order);
        let points: u16 = (0..4)
            .flat_map(|seat| arrangements[seat as usize][beat_index].iter())
            .map(|card| u16::from(card.points()))
            .sum();
        scores[winner as usize] += points;
        let labels = [
            groups[order[0] as usize].label.clone(),
            groups[order[1] as usize].label.clone(),
            groups[order[2] as usize].label.clone(),
            groups[order[3] as usize].label.clone(),
        ];
        let hands = [
            arrangements[order[0] as usize][beat_index].clone(),
            arrangements[order[1] as usize][beat_index].clone(),
            arrangements[order[2] as usize][beat_index].clone(),
            arrangements[order[3] as usize][beat_index].clone(),
        ];
        let spares = [
            groups[order[0] as usize].spare,
            groups[order[1] as usize].spare,
            groups[order[2] as usize].spare,
            groups[order[3] as usize].spare,
        ];
        beats.push(Beat {
            leader,
            order,
            winner,
            points,
            tied,
            labels,
            hands,
            spares,
        });
        leader = winner;
    }
    DealResult {
        beats: beats.try_into().expect("four beats"),
        scores,
    }
}

fn play_order(leader: u8) -> [u8; 4] {
    [leader, (leader + 1) % 4, (leader + 2) % 4, (leader + 3) % 4]
}

/// Later seat in this beat's play order wins an equal combination.
fn winner_in_order(groups: &[Combo], order: [u8; 4]) -> (u8, bool) {
    let mut best_pos = 0usize;
    let mut tied = false;
    for pos in 1..4 {
        let cmp = compare_combo(
            &groups[order[pos] as usize],
            &groups[order[best_pos] as usize],
        );
        if cmp > 0 {
            best_pos = pos;
            tied = false;
        } else if cmp == 0 {
            best_pos = pos;
            tied = true;
        }
    }
    (order[best_pos], tied)
}
