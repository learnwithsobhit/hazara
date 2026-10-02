//! One match, owned by a single task. The rules crate decides legality and scores.

use std::collections::HashSet;
use std::time::{SystemTime, UNIX_EPOCH};

use hazara_domain::{standard_deck, Card};
use hazara_engine::{
    deterministic_legal, play_deal, validate_arrangement, ArrangeError, DealResult,
};
use rand::seq::SliceRandom;
use rand::thread_rng;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Length {
    OneDeal,
    Short,
    Full,
}

impl Length {
    pub fn parse(raw: &str) -> Option<Self> {
        match raw {
            "one_deal" => Some(Self::OneDeal),
            "short" => Some(Self::Short),
            "full" => Some(Self::Full),
            _ => None,
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::OneDeal => "one_deal",
            Self::Short => "short",
            Self::Full => "full",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SeatStatus {
    Arranging,
    Ready,
    Reconnecting,
    Auto,
}

#[derive(Clone, Debug)]
pub struct Seat {
    pub player_id: Uuid,
    pub name: String,
    pub status: SeatStatus,
}

#[derive(Clone, Debug, Serialize)]
pub struct BeatView {
    pub winner: String,
    pub points: u16,
    pub tied: bool,
    pub rows: Vec<BeatRow>,
}

#[derive(Clone, Debug, Serialize)]
pub struct BeatRow {
    pub name: String,
    pub label: String,
    pub cards: Vec<String>,
    pub spare: Option<String>,
}

#[derive(Clone, Debug, Serialize)]
pub struct Snapshot {
    pub phase: &'static str,
    pub match_length: &'static str,
    pub you: u8,
    pub deal_no: u32,
    pub match_over: bool,
    pub you_are_host: bool,
    pub locked: bool,
    pub hand: Vec<String>,
    pub seats: Vec<SeatView>,
    pub scores: [u16; 4],
    pub beats: Vec<BeatView>,
    pub note: Option<String>,
    pub arrange_deadline_ms: u64,
    pub reveal_index: u8,
    pub reveal_until_ms: u64,
    pub server_now: u64,
    pub protocol: u32,
    pub auto_locked: bool,
    pub sealed: Vec<Vec<String>>,
    pub dealer: u8,
}

#[derive(Clone, Debug, Serialize)]
pub struct SeatView {
    pub seat: u8,
    pub name: String,
    pub status: SeatStatus,
    pub you: bool,
    pub host: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SavedSeat {
    pub player_id: Uuid,
    pub name: String,
    pub status: SeatStatus,
}

/// Durable match. Card faces live here, never in logs.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SavedTable {
    pub seats: [SavedSeat; 4],
    pub holes: [Vec<String>; 4],
    pub drafts: [Option<[Vec<String>; 4]>; 4],
    pub sealed: [Option<[Vec<String>; 4]>; 4],
    pub auto: [bool; 4],
    pub seen_actions: Vec<String>,
    pub length: String,
    pub dealer: u8,
    pub deal_no: u32,
    pub totals: [u16; 4],
    pub phase: String,
    pub deadline_id: u64,
    pub summary_id: u64,
    pub grace_gen: [u64; 4],
    pub notes: [Option<String>; 4],
    pub deadline_ms: u64,
    #[serde(default)]
    pub reveal_index: u8,
    #[serde(default)]
    pub reveal_gen: u64,
    #[serde(default)]
    pub reveal_until_ms: u64,
    /// Host pressed "End match" before the natural end condition.
    #[serde(default)]
    pub force_ended: bool,
    #[serde(default)]
    pub host_seat: u8,
}

pub struct Table {
    pub seats: [Seat; 4],
    holes: [Vec<Card>; 4],
    drafts: [Option<[Vec<Card>; 4]>; 4],
    sealed: [Option<[Vec<Card>; 4]>; 4],
    auto: [bool; 4],
    seen_actions: HashSet<String>,
    pub length: Length,
    pub dealer: u8,
    pub deal_no: u32,
    pub totals: [u16; 4],
    pub phase: Phase,
    result: Option<DealResult>,
    pub deadline_id: u64,
    pub summary_id: u64,
    pub grace_gen: [u64; 4],
    notes: [Option<String>; 4],
    deadline_ms: u64,
    reveal_index: u8,
    reveal_gen: u64,
    reveal_until_ms: u64,
    force_ended: bool,
    pub host_seat: u8,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Phase {
    Arranging,
    Reveal,
    Summary,
}

impl Table {
    pub fn deal(seats: [Seat; 4], length: Length) -> Self {
        let mut table = Self {
            seats,
            holes: Default::default(),
            drafts: Default::default(),
            sealed: Default::default(),
            auto: [false; 4],
            seen_actions: HashSet::new(),
            length,
            dealer: 0,
            deal_no: 0,
            totals: [0; 4],
            phase: Phase::Arranging,
            result: None,
            deadline_id: 0,
            summary_id: 0,
            grace_gen: [0; 4],
            notes: Default::default(),
            deadline_ms: 0,
            reveal_index: 0,
            reveal_gen: 0,
            reveal_until_ms: 0,
            force_ended: false,
            host_seat: 0,
        };
        table.shuffle_deal();
        table
    }

    /// Fixed holes for tests. Production deals go through [`Table::deal`].
    #[cfg_attr(not(test), allow(dead_code))]
    pub fn from_holes(seats: [Seat; 4], length: Length, holes: [Vec<Card>; 4]) -> Self {
        Self {
            seats,
            holes,
            drafts: Default::default(),
            sealed: Default::default(),
            auto: [false; 4],
            seen_actions: HashSet::new(),
            length,
            dealer: 0,
            deal_no: 1,
            totals: [0; 4],
            phase: Phase::Arranging,
            result: None,
            deadline_id: 1,
            summary_id: 0,
            grace_gen: [0; 4],
            notes: Default::default(),
            deadline_ms: now_ms().saturating_add(120_000),
            reveal_index: 0,
            reveal_gen: 0,
            reveal_until_ms: 0,
            force_ended: false,
            host_seat: 0,
        }
    }

    pub fn seat_of(&self, player: Uuid) -> Option<u8> {
        self.seats
            .iter()
            .position(|seat| seat.player_id == player)
            .map(|index| index as u8)
    }

    pub fn save_draft(&mut self, seat: u8, sets: [Vec<Card>; 4]) -> Result<(), String> {
        self.ensure_arranging(seat)?;
        if !covers_hole(&self.holes[seat as usize], &sets) {
            return Err("Those cards are not your hand.".into());
        }
        self.drafts[seat as usize] = Some(sets);
        Ok(())
    }

    pub fn ready(
        &mut self,
        seat: u8,
        action_id: &str,
        sets: [Vec<Card>; 4],
    ) -> Result<bool, String> {
        if self.seen_actions.contains(action_id) {
            return Ok(false);
        }
        self.ensure_arranging(seat)?;
        let hole = &self.holes[seat as usize];
        if !same_cards(hole, &sets) {
            return Err("Those cards are not your hand.".into());
        }
        validate_arrangement(&sets).map_err(arrange_message)?;
        self.sealed[seat as usize] = Some(sets);
        self.auto[seat as usize] = false;
        self.seats[seat as usize].status = SeatStatus::Ready;
        self.notes[seat as usize] = None;
        self.seen_actions.insert(action_id.to_string());
        self.maybe_reveal();
        Ok(true)
    }

    pub fn disconnect(&mut self, seat: u8) -> u64 {
        self.grace_gen[seat as usize] += 1;
        self.seats[seat as usize].status = SeatStatus::Reconnecting;
        self.grace_gen[seat as usize]
    }

    pub fn reconnect(&mut self, seat: u8) {
        self.grace_gen[seat as usize] += 1;
        if self.sealed[seat as usize].is_some() {
            self.seats[seat as usize].status = if self.auto[seat as usize] {
                SeatStatus::Auto
            } else {
                SeatStatus::Ready
            };
        } else if self.phase == Phase::Arranging {
            self.seats[seat as usize].status = SeatStatus::Arranging;
        }
    }

    #[allow(dead_code)]
    pub fn grace_expired(&mut self, seat: u8, gen: u64) {
        if self.grace_gen[seat as usize] != gen || self.phase != Phase::Arranging {
            return;
        }
        if self.sealed[seat as usize].is_some() {
            return;
        }
        self.lock_seat(seat, true);
        self.maybe_reveal();
    }

    #[allow(dead_code)]
    pub fn deadline(&mut self, id: u64) {
        if self.deadline_id != id || self.phase != Phase::Arranging {
            return;
        }
        for seat in 0..4 {
            if self.sealed[seat].is_none() {
                self.lock_seat(seat as u8, true);
            }
        }
        self.maybe_reveal();
    }

    pub fn next_deal(&mut self, seat: u8, summary_id: u64) -> Result<(), String> {
        if seat != self.host_seat {
            return Err("The host starts the next deal.".into());
        }
        if self.phase != Phase::Summary || self.summary_id != summary_id {
            return Err("The table is not waiting for the next deal.".into());
        }
        if self.is_over() {
            return Err("This match is finished.".into());
        }
        self.dealer = (self.dealer + 1) % 4;
        self.shuffle_deal();
        Ok(())
    }

    /// Same people, same room, scores back to zero. Host only, after the match ends.
    pub fn rematch(&mut self, seat: u8) -> Result<(), String> {
        if seat != self.host_seat {
            return Err("Only the host can play again.".into());
        }
        if self.phase != Phase::Summary || !self.is_over() {
            return Err("This match is still going.".into());
        }
        self.totals = [0; 4];
        self.deal_no = 0;
        self.dealer = 0;
        self.seen_actions.clear();
        self.result = None;
        self.summary_id += 1;
        self.shuffle_deal();
        Ok(())
    }

    fn own_sealed(&self, seat: u8) -> Vec<Vec<String>> {
        if self.phase != Phase::Arranging {
            return Vec::new();
        }
        let Some(sets) = &self.sealed[seat as usize] else {
            return Vec::new();
        };
        sets.iter()
            .map(|cards| cards.iter().map(|card| card.id()).collect())
            .collect()
    }

    pub fn snapshot(&self, seat: u8) -> Snapshot {
        let mut seats = Vec::new();
        for (index, person) in self.seats.iter().enumerate() {
            seats.push(SeatView {
                seat: index as u8,
                name: person.name.clone(),
                status: person.status,
                you: index as u8 == seat,
                host: index as u8 == self.host_seat,
            });
        }
        let all = self
            .result
            .as_ref()
            .map(|result| beat_views(&self.seats, result))
            .unwrap_or_default();
        let beats = match self.phase {
            Phase::Arranging => Vec::new(),
            Phase::Reveal => all
                .into_iter()
                .skip(self.reveal_index as usize)
                .take(1)
                .collect(),
            Phase::Summary => all,
        };
        Snapshot {
            phase: match self.phase {
                Phase::Arranging => "arranging",
                Phase::Reveal => "reveal",
                Phase::Summary => "summary",
            },
            match_length: self.length.as_str(),
            you: seat,
            deal_no: self.deal_no,
            match_over: self.phase == Phase::Summary && self.is_over(),
            you_are_host: seat == self.host_seat,
            locked: self.sealed[seat as usize].is_some(),
            hand: if self.phase == Phase::Arranging {
                self.holes[seat as usize]
                    .iter()
                    .map(|card| card.id())
                    .collect()
            } else {
                Vec::new()
            },
            seats,
            scores: self.totals,
            beats,
            note: self.notes[seat as usize].clone(),
            arrange_deadline_ms: 0,
            reveal_index: self.reveal_index,
            reveal_until_ms: if self.phase == Phase::Reveal {
                self.reveal_until_ms
            } else {
                0
            },
            server_now: now_ms(),
            protocol: PROTOCOL_VERSION,
            auto_locked: self.auto[seat as usize],
            sealed: self.own_sealed(seat),
            dealer: self.dealer,
        }
    }

    pub fn reveal_gen(&self) -> u64 {
        self.reveal_gen
    }

    pub fn reveal_until_ms(&self) -> u64 {
        self.reveal_until_ms
    }

    /// Private deal, locks, and scores. Written before the table acknowledges a move.
    pub fn export(&self) -> SavedTable {
        let mut seen_actions: Vec<String> = self.seen_actions.iter().cloned().collect();
        seen_actions.sort();
        SavedTable {
            seats: self.seats.clone().map(|seat| SavedSeat {
                player_id: seat.player_id,
                name: seat.name,
                status: seat.status,
            }),
            holes: self
                .holes
                .clone()
                .map(|cards| cards.iter().map(|card| card.id()).collect()),
            drafts: self.drafts.clone().map(|draft| {
                draft.map(|sets| sets.map(|cards| cards.iter().map(|card| card.id()).collect()))
            }),
            sealed: self.sealed.clone().map(|sealed| {
                sealed.map(|sets| sets.map(|cards| cards.iter().map(|card| card.id()).collect()))
            }),
            auto: self.auto,
            seen_actions,
            length: self.length.as_str().to_string(),
            dealer: self.dealer,
            deal_no: self.deal_no,
            totals: self.totals,
            phase: match self.phase {
                Phase::Arranging => "arranging",
                Phase::Reveal => "reveal",
                Phase::Summary => "summary",
            }
            .to_string(),
            deadline_id: self.deadline_id,
            summary_id: self.summary_id,
            grace_gen: self.grace_gen,
            notes: self.notes.clone(),
            deadline_ms: self.deadline_ms,
            reveal_index: self.reveal_index,
            reveal_gen: self.reveal_gen,
            reveal_until_ms: self.reveal_until_ms,
            force_ended: self.force_ended,
            host_seat: self.host_seat,
        }
    }

    pub fn restore(saved: &SavedTable) -> Result<Self, String> {
        let length = Length::parse(&saved.length)
            .ok_or_else(|| "Saved match length is unreadable.".to_string())?;
        let phase = match saved.phase.as_str() {
            "arranging" => Phase::Arranging,
            "reveal" => Phase::Reveal,
            "summary" => Phase::Summary,
            _ => return Err("Saved match phase is unreadable.".into()),
        };
        let holes = saved
            .holes
            .iter()
            .map(|cards| cards_from(cards))
            .collect::<Result<Vec<_>, _>>()?
            .try_into()
            .map_err(|_| "Saved hands are unreadable.".to_string())?;
        let drafts = saved
            .drafts
            .iter()
            .map(|draft| draft.as_ref().map(sets_from_ids).transpose())
            .collect::<Result<Vec<_>, _>>()?
            .try_into()
            .map_err(|_| "Saved drafts are unreadable.".to_string())?;
        let sealed = saved
            .sealed
            .iter()
            .map(|sealed| sealed.as_ref().map(sets_from_ids).transpose())
            .collect::<Result<Vec<_>, _>>()?
            .try_into()
            .map_err(|_| "Saved locks are unreadable.".to_string())?;
        let seats = saved.seats.clone().map(|seat| Seat {
            player_id: seat.player_id,
            name: seat.name,
            status: seat.status,
        });
        let mut table = Self {
            seats,
            holes,
            drafts,
            sealed,
            auto: saved.auto,
            seen_actions: saved.seen_actions.iter().cloned().collect(),
            length,
            dealer: saved.dealer,
            deal_no: saved.deal_no,
            totals: saved.totals,
            phase,
            result: None,
            deadline_id: saved.deadline_id,
            summary_id: saved.summary_id,
            grace_gen: saved.grace_gen,
            notes: saved.notes.clone(),
            deadline_ms: saved.deadline_ms,
            reveal_index: saved.reveal_index,
            reveal_gen: saved.reveal_gen,
            reveal_until_ms: saved.reveal_until_ms,
            force_ended: saved.force_ended,
            host_seat: saved.host_seat,
        };
        if (phase == Phase::Summary || phase == Phase::Reveal)
            && table.sealed.iter().all(|set| set.is_some())
        {
            let arrangements = [
                table.sealed[0].clone().unwrap(),
                table.sealed[1].clone().unwrap(),
                table.sealed[2].clone().unwrap(),
                table.sealed[3].clone().unwrap(),
            ];
            table.result = Some(play_deal(&arrangements, table.dealer));
        }
        Ok(table)
    }

    fn lock_seat(&mut self, seat: u8, from_timeout: bool) {
        if self.sealed[seat as usize].is_some() {
            return;
        }
        let hole = self.holes[seat as usize].clone();
        let chosen = self.drafts[seat as usize]
            .clone()
            .filter(|sets| validate_arrangement(sets).is_ok())
            .or_else(|| deterministic_legal(&hole).ok());
        let Some(sets) = chosen else {
            return;
        };
        let had_valid_draft = self.drafts[seat as usize]
            .as_ref()
            .is_some_and(|sets| validate_arrangement(sets).is_ok());
        self.sealed[seat as usize] = Some(sets);
        self.auto[seat as usize] = from_timeout;
        self.seats[seat as usize].status = if from_timeout {
            SeatStatus::Auto
        } else {
            SeatStatus::Ready
        };
        if from_timeout {
            self.notes[seat as usize] = Some(if had_valid_draft {
                "Time ran out. We locked your last saved hand.".into()
            } else {
                "Time ran out. We arranged a legal hand so the table could continue.".into()
            });
        }
    }

    fn maybe_reveal(&mut self) {
        if self.sealed.iter().any(|set| set.is_none()) {
            return;
        }
        let arrangements = [
            self.sealed[0].clone().unwrap(),
            self.sealed[1].clone().unwrap(),
            self.sealed[2].clone().unwrap(),
            self.sealed[3].clone().unwrap(),
        ];
        let result = play_deal(&arrangements, self.dealer);
        for (index, points) in result.scores.iter().enumerate() {
            self.totals[index] += points;
        }
        self.result = Some(result);
        self.phase = Phase::Reveal;
        self.reveal_index = 0;
        self.reveal_gen += 1;
        self.reveal_until_ms = now_ms().saturating_add(dwell_ms(0));
    }

    /// Shows the next set, or opens the summary after the spare set.
    /// Returns whether the table is still revealing.
    pub fn advance_reveal(&mut self, gen: u64) -> bool {
        if self.phase != Phase::Reveal || gen != self.reveal_gen {
            return self.phase == Phase::Reveal;
        }
        if self.reveal_index >= 3 {
            self.phase = Phase::Summary;
            self.summary_id += 1;
            return false;
        }
        self.reveal_index += 1;
        self.reveal_gen += 1;
        self.reveal_until_ms = now_ms().saturating_add(dwell_ms(self.reveal_index));
        true
    }

    fn shuffle_deal(&mut self) {
        let mut deck = standard_deck();
        deck.shuffle(&mut thread_rng());
        for seat in 0..4 {
            self.holes[seat] = deck[seat * 13..(seat + 1) * 13].to_vec();
            self.drafts[seat] = None;
            self.sealed[seat] = None;
            self.auto[seat] = false;
            self.notes[seat] = None;
            self.seats[seat].status = SeatStatus::Arranging;
        }
        self.result = None;
        self.phase = Phase::Arranging;
        self.reveal_index = 0;
        self.deal_no += 1;
        self.deadline_id += 1;
        self.deadline_ms = now_ms().saturating_add(120_000);
    }

    fn ensure_arranging(&self, seat: u8) -> Result<(), String> {
        if self.phase != Phase::Arranging {
            return Err("The table already locked your hand.".into());
        }
        if self.sealed[seat as usize].is_some() {
            return Err("The table already locked your hand.".into());
        }
        Ok(())
    }

    pub fn is_over(&self) -> bool {
        if self.force_ended && self.phase == Phase::Summary {
            return true;
        }
        match self.length {
            Length::OneDeal => self.deal_no >= 1 && self.phase == Phase::Summary,
            Length::Short => self.deal_no >= 3 && self.phase == Phase::Summary,
            Length::Full => {
                let max = self.totals.iter().copied().max().unwrap_or(0);
                max >= 1000 && self.totals.iter().filter(|score| **score == max).count() == 1
            }
        }
    }

    /// Host can force-end the match from the Summary or Arranging phase.
    pub fn force_end(&mut self, seat: u8) -> Result<(), String> {
        if seat != self.host_seat {
            return Err("Only the host can end the match.".into());
        }
        if self.phase == Phase::Reveal {
            return Err("Wait for the current reveal to finish.".into());
        }
        if self.is_over() {
            return Err("This match is already over.".into());
        }
        // If we're in Arranging, move to Summary first so is_over() can fire.
        if self.phase == Phase::Arranging {
            // Synthesise a zero result so the Summary screen renders gracefully.
            self.phase = Phase::Summary;
            self.summary_id += 1;
        }
        self.force_ended = true;
        Ok(())
    }

    /// Hands the host role to the next seat that is still connected.
    pub fn pass_host_if_needed(&mut self, disconnected_seat: u8) {
        if self.host_seat != disconnected_seat {
            return;
        }
        for offset in 1..4 {
            let next = (disconnected_seat as usize + offset) % 4;
            if self.seats[next].status != SeatStatus::Reconnecting {
                self.host_seat = next as u8;
                return;
            }
        }
    }

    /// Gives the first disconnected seat to a new player, keeping its hand.
    pub fn claim_vacant_seat(&mut self, new_player: Uuid, new_name: String) -> Result<u8, String> {
        let Some(i) = self
            .seats
            .iter()
            .position(|seat| seat.status == SeatStatus::Reconnecting)
        else {
            return Err("That table has already started and every seat is taken.".into());
        };
        let already_locked = self.sealed[i].is_some() || self.phase != Phase::Arranging;
        self.seats[i].player_id = new_player;
        self.seats[i].name = new_name;
        self.seats[i].status = if already_locked {
            SeatStatus::Ready
        } else {
            SeatStatus::Arranging
        };
        if !already_locked {
            self.drafts[i] = None;
            self.auto[i] = false;
        }
        Ok(i as u8)
    }
}

fn dwell_ms(index: u8) -> u64 {
    if index >= 3 {
        6_000
    } else {
        4_500
    }
}

fn beat_views(seats: &[Seat; 4], result: &DealResult) -> Vec<BeatView> {
    result
        .beats
        .iter()
        .map(|beat| BeatView {
            winner: seats[beat.winner as usize].name.clone(),
            points: beat.points,
            tied: beat.tied,
            rows: beat
                .order
                .iter()
                .zip(beat.labels.iter())
                .map(|(seat, label)| {
                    let index = beat.order.iter().position(|item| item == seat).unwrap_or(0);
                    BeatRow {
                        name: seats[*seat as usize].name.clone(),
                        label: label.clone(),
                        cards: beat.hands[index].iter().map(|card| card.id()).collect(),
                        spare: beat.spares[index].map(|card| card.id()),
                    }
                })
                .collect(),
        })
        .collect()
}

fn covers_hole(hole: &[Card], sets: &[Vec<Card>; 4]) -> bool {
    let placed: Vec<&Card> = sets.iter().flatten().collect();
    let unique = placed.iter().collect::<HashSet<_>>();
    placed.len() == unique.len() && placed.into_iter().all(|card| hole.contains(card))
}

fn cards_from(ids: &[String]) -> Result<Vec<Card>, String> {
    ids.iter()
        .map(|id| parse_card(id).ok_or_else(|| "Saved cards are unreadable.".to_string()))
        .collect()
}

fn sets_from_ids(ids: &[Vec<String>; 4]) -> Result<[Vec<Card>; 4], String> {
    let groups = ids.to_vec();
    parse_sets(&groups)
}

pub(crate) const PROTOCOL_VERSION: u32 = hazara_protocol::PROTOCOL_VERSION;

pub(crate) fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}

fn same_cards(hole: &[Card], sets: &[Vec<Card>; 4]) -> bool {
    let mut dealt = sets.iter().flatten().copied().collect::<Vec<_>>();
    let mut original = hole.to_vec();
    dealt.sort_by_key(|a| a.id());
    original.sort_by_key(|a| a.id());
    dealt.len() == 13 && dealt == original
}

fn arrange_message(error: ArrangeError) -> String {
    match error {
        ArrangeError::NotDescending => {
            "Sets must go strongest to weakest. Swap them to continue.".into()
        }
        ArrangeError::WrongSize | ArrangeError::NotThirteen => "Place all 13 cards.".into(),
        ArrangeError::DuplicateCard => "Those cards are already in another set.".into(),
        ArrangeError::NoLegal => "We could not lock a legal hand.".into(),
    }
}

pub fn parse_sets(raw: &[Vec<String>]) -> Result<[Vec<Card>; 4], String> {
    if raw.len() != 4 {
        return Err("Place all 13 cards.".into());
    }
    let mut sets: [Vec<Card>; 4] = Default::default();
    for (index, group) in raw.iter().enumerate() {
        for token in group {
            sets[index].push(
                parse_card(token).ok_or_else(|| "Those cards are not your hand.".to_string())?,
            );
        }
    }
    Ok(sets)
}

pub fn parse_card(raw: &str) -> Option<Card> {
    let (suit_name, rank_name) = raw.split_once('-')?;
    let suit = match suit_name {
        "clubs" => hazara_domain::Suit::Clubs,
        "diamonds" => hazara_domain::Suit::Diamonds,
        "hearts" => hazara_domain::Suit::Hearts,
        "spades" => hazara_domain::Suit::Spades,
        _ => return None,
    };
    let rank = match rank_name {
        "two" => hazara_domain::Rank::Two,
        "three" => hazara_domain::Rank::Three,
        "four" => hazara_domain::Rank::Four,
        "five" => hazara_domain::Rank::Five,
        "six" => hazara_domain::Rank::Six,
        "seven" => hazara_domain::Rank::Seven,
        "eight" => hazara_domain::Rank::Eight,
        "nine" => hazara_domain::Rank::Nine,
        "ten" => hazara_domain::Rank::Ten,
        "jack" => hazara_domain::Rank::Jack,
        "queen" => hazara_domain::Rank::Queen,
        "king" => hazara_domain::Rank::King,
        "ace" => hazara_domain::Rank::Ace,
        _ => return None,
    };
    Some(Card::new(suit, rank))
}

#[cfg(test)]
mod tests {
    use super::*;
    use hazara_engine::deterministic_legal;

    fn people() -> [Seat; 4] {
        ["Ada", "Bo", "Cy", "Di"]
            .into_iter()
            .map(|name| Seat {
                player_id: Uuid::new_v4(),
                name: name.to_string(),
                status: SeatStatus::Arranging,
            })
            .collect::<Vec<_>>()
            .try_into()
            .unwrap()
    }

    fn dealt() -> (Table, [Vec<Card>; 4]) {
        let deck = standard_deck();
        let holes = [
            deck[0..13].to_vec(),
            deck[13..26].to_vec(),
            deck[26..39].to_vec(),
            deck[39..52].to_vec(),
        ];
        let table = Table::from_holes(people(), Length::Short, holes.clone());
        (table, holes)
    }

    fn seal_all(table: &mut Table, holes: &[Vec<Card>; 4], prefix: &str) {
        for (seat, hole) in holes.iter().enumerate() {
            let sets = deterministic_legal(hole).unwrap();
            assert!(table
                .ready(seat as u8, &format!("{prefix}{seat}"), sets)
                .unwrap());
        }
    }

    #[test]
    fn deal_scores_sum_to_360() {
        let (mut table, holes) = dealt();
        seal_all(&mut table, &holes, "deal-");
        assert_eq!(table.phase, Phase::Reveal);
        assert_eq!(table.snapshot(0).beats.len(), 1);
        assert_eq!(table.totals.iter().sum::<u16>(), 360);
        for _ in 0..4 {
            let gen = table.reveal_gen();
            table.advance_reveal(gen);
        }
        assert_eq!(table.phase, Phase::Summary);
        assert_eq!(table.snapshot(0).beats.len(), 4);
        assert_eq!(table.totals.iter().sum::<u16>(), 360);
    }

    #[test]
    fn duplicate_ready_does_not_double_score() {
        let (mut table, holes) = dealt();
        let first = deterministic_legal(&holes[0]).unwrap();
        assert!(table.ready(0, "a0", first.clone()).unwrap());
        assert!(!table.ready(0, "a0", first.clone()).unwrap());
        for (seat, hole) in holes.iter().enumerate().skip(1) {
            let sets = deterministic_legal(hole).unwrap();
            assert!(table.ready(seat as u8, &format!("a{seat}"), sets).unwrap());
        }
        let totals = table.totals;
        assert_eq!(totals.iter().sum::<u16>(), 360);
        assert!(table.ready(0, "other", first).is_err());
        assert_eq!(table.totals, totals);
        assert!(!table
            .ready(0, "a0", deterministic_legal(&holes[0]).unwrap())
            .unwrap());
        assert_eq!(table.totals, totals);
    }

    #[test]
    fn snapshot_omits_other_hole_cards() {
        let (table, holes) = dealt();
        let snap = table.snapshot(0);
        let json = serde_json::to_string(&snap).unwrap();
        assert_eq!(snap.hand.len(), 13);
        for card in &holes[0] {
            assert!(snap.hand.iter().any(|id| id == &card.id()));
        }
        for hole in &holes[1..] {
            for card in hole {
                assert!(
                    !json.contains(&card.id()),
                    "seat 0 snapshot leaked {}",
                    card.id()
                );
            }
        }
    }

    #[test]
    fn deadline_locks_a_legal_hand_once() {
        let (mut table, _) = dealt();
        let id = table.deadline_id;
        table.deadline(id);
        assert_eq!(table.phase, Phase::Reveal);
        assert_eq!(table.totals.iter().sum::<u16>(), 360);
        let note = table.snapshot(0).note.unwrap();
        assert!(note.contains("legal hand"));
        let totals = table.totals;
        table.deadline(id);
        assert_eq!(table.totals, totals);
    }

    #[test]
    fn restore_keeps_the_hand_the_lock_and_the_score() {
        let (mut table, holes) = dealt();
        let sets = deterministic_legal(&holes[0]).unwrap();
        assert!(table.ready(0, "lock-0", sets.clone()).unwrap());
        let saved = table.export();
        let mut restored = Table::restore(&saved).unwrap();
        assert_eq!(restored.phase, Phase::Arranging);
        assert_eq!(restored.snapshot(0).hand, table.snapshot(0).hand);
        assert!(restored.snapshot(0).locked);
        assert!(!restored.snapshot(1).locked);
        assert!(!restored.ready(0, "lock-0", sets).unwrap());
        assert_eq!(restored.totals, table.totals);
        let id = restored.deadline_id;
        restored.deadline(id);
        for _ in 0..4 {
            let gen = restored.reveal_gen();
            restored.advance_reveal(gen);
        }
        assert_eq!(restored.phase, Phase::Summary);
        assert_eq!(restored.totals.iter().sum::<u16>(), 360);
        let again = Table::restore(&restored.export()).unwrap();
        assert_eq!(again.phase, Phase::Summary);
        assert_eq!(again.totals, restored.totals);
        assert_eq!(again.snapshot(0).beats.len(), 4);
    }

    #[test]
    fn rematch_clears_the_score_and_deals_again() {
        let deck = standard_deck();
        let holes = [
            deck[0..13].to_vec(),
            deck[13..26].to_vec(),
            deck[26..39].to_vec(),
            deck[39..52].to_vec(),
        ];
        let mut table = Table::from_holes(people(), Length::OneDeal, holes.clone());
        seal_all(&mut table, &holes, "end-");
        for _ in 0..4 {
            let gen = table.reveal_gen();
            table.advance_reveal(gen);
        }
        assert!(table.snapshot(0).match_over);
        assert!(table.rematch(1).is_err());
        table.rematch(0).unwrap();
        assert_eq!(table.phase, Phase::Arranging);
        assert_eq!(table.totals, [0; 4]);
        assert_eq!(table.deal_no, 1);
        assert!(!table.snapshot(0).locked);
        assert_eq!(table.snapshot(0).protocol, PROTOCOL_VERSION);
        assert!(table.snapshot(0).server_now > 0);
    }

    #[test]
    fn host_passes_to_the_next_connected_seat() {
        let (mut table, _) = dealt();
        assert!(table.snapshot(0).you_are_host);
        table.disconnect(0);
        table.pass_host_if_needed(0);
        assert!(!table.snapshot(0).you_are_host);
        assert!(table.snapshot(1).you_are_host);
        assert!(table.snapshot(1).seats[1].host);
        assert!(!table.snapshot(1).seats[0].host);
    }

    #[test]
    fn claim_vacant_seat_keeps_the_hole_and_a_lock() {
        let (mut table, holes) = dealt();
        let sets = deterministic_legal(&holes[1]).unwrap();
        assert!(table.ready(1, "lock-1", sets).unwrap());
        table.disconnect(1);
        let new_id = Uuid::new_v4();
        let seat = table
            .claim_vacant_seat(new_id, "Eve".into())
            .unwrap();
        assert_eq!(seat, 1);
        let snap = table.snapshot(1);
        assert_eq!(snap.seats[1].name, "Eve");
        assert!(snap.locked);
        assert_eq!(snap.hand.len(), 13);
    }

    #[test]
    fn claim_fails_when_every_seat_is_present() {
        let (mut table, _) = dealt();
        let err = table
            .claim_vacant_seat(Uuid::new_v4(), "Eve".into())
            .unwrap_err();
        assert!(err.contains("every seat is taken"));
    }
}
