//! Cards and point values for HAZARA rules.v1. No I/O.

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Suit {
    Clubs,
    Diamonds,
    Hearts,
    Spades,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Rank {
    Two,
    Three,
    Four,
    Five,
    Six,
    Seven,
    Eight,
    Nine,
    Ten,
    Jack,
    Queen,
    King,
    Ace,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct Card {
    pub suit: Suit,
    pub rank: Rank,
}

impl Suit {
    pub const ALL: [Suit; 4] = [Suit::Clubs, Suit::Diamonds, Suit::Hearts, Suit::Spades];

    pub fn name(self) -> &'static str {
        match self {
            Suit::Clubs => "clubs",
            Suit::Diamonds => "diamonds",
            Suit::Hearts => "hearts",
            Suit::Spades => "spades",
        }
    }
}

impl Rank {
    pub const ALL: [Rank; 13] = [
        Rank::Two,
        Rank::Three,
        Rank::Four,
        Rank::Five,
        Rank::Six,
        Rank::Seven,
        Rank::Eight,
        Rank::Nine,
        Rank::Ten,
        Rank::Jack,
        Rank::Queen,
        Rank::King,
        Rank::Ace,
    ];

    /// Ace is 14. Two is 2. King is 13.
    pub fn ace_high(self) -> u8 {
        match self {
            Rank::Ace => 14,
            other => other as u8 + 2,
        }
    }

    pub fn points(self) -> u8 {
        match self {
            Rank::Ace | Rank::King | Rank::Queen | Rank::Jack | Rank::Ten => 10,
            _ => 5,
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            Rank::Ace => "A",
            Rank::King => "K",
            Rank::Queen => "Q",
            Rank::Jack => "J",
            Rank::Ten => "10",
            Rank::Nine => "9",
            Rank::Eight => "8",
            Rank::Seven => "7",
            Rank::Six => "6",
            Rank::Five => "5",
            Rank::Four => "4",
            Rank::Three => "3",
            Rank::Two => "2",
        }
    }

    pub fn plural(self) -> &'static str {
        match self {
            Rank::Ace => "Aces",
            Rank::King => "Kings",
            Rank::Queen => "Queens",
            Rank::Jack => "Jacks",
            Rank::Ten => "Tens",
            Rank::Nine => "Nines",
            Rank::Eight => "Eights",
            Rank::Seven => "Sevens",
            Rank::Six => "Sixes",
            Rank::Five => "Fives",
            Rank::Four => "Fours",
            Rank::Three => "Threes",
            Rank::Two => "Twos",
        }
    }

    pub fn name(self) -> &'static str {
        match self {
            Rank::Two => "two",
            Rank::Three => "three",
            Rank::Four => "four",
            Rank::Five => "five",
            Rank::Six => "six",
            Rank::Seven => "seven",
            Rank::Eight => "eight",
            Rank::Nine => "nine",
            Rank::Ten => "ten",
            Rank::Jack => "jack",
            Rank::Queen => "queen",
            Rank::King => "king",
            Rank::Ace => "ace",
        }
    }
}

impl Card {
    pub const fn new(suit: Suit, rank: Rank) -> Self {
        Self { suit, rank }
    }

    /// Same identity string as the Flutter client: `hearts-ace`.
    pub fn id(self) -> String {
        format!("{}-{}", self.suit.name(), self.rank.name())
    }

    pub fn points(self) -> u8 {
        self.rank.points()
    }
}

pub fn standard_deck() -> Vec<Card> {
    let mut deck = Vec::with_capacity(52);
    for suit in Suit::ALL {
        for rank in Rank::ALL {
            deck.push(Card::new(suit, rank));
        }
    }
    deck
}

pub fn deck_points() -> u16 {
    standard_deck()
        .iter()
        .map(|card| u16::from(card.points()))
        .sum()
}
