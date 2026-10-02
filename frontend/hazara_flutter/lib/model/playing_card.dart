enum Suit { clubs, diamonds, hearts, spades }

enum Rank {
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
  ace,
}

class PlayingCard {
  const PlayingCard(this.suit, this.rank);

  final Suit suit;
  final Rank rank;

  String get id => '${suit.name}-${rank.name}';

  static PlayingCard parse(String id) {
    final parts = id.split('-');
    return PlayingCard(
      Suit.values.byName(parts[0]),
      Rank.values.byName(parts[1]),
    );
  }

  int get aceHigh {
    if (rank == Rank.ace) return 14;
    return rank.index + 2;
  }

  int get points {
    switch (rank) {
      case Rank.ace:
      case Rank.king:
      case Rank.queen:
      case Rank.jack:
      case Rank.ten:
        return 10;
      default:
        return 5;
    }
  }

  String get rankLabel {
    switch (rank) {
      case Rank.ace:
        return 'A';
      case Rank.king:
        return 'K';
      case Rank.queen:
        return 'Q';
      case Rank.jack:
        return 'J';
      case Rank.ten:
        return '10';
      default:
        return '${rank.index + 2}';
    }
  }

  String get rankPlural {
    switch (rank) {
      case Rank.ace:
        return 'Aces';
      case Rank.king:
        return 'Kings';
      case Rank.queen:
        return 'Queens';
      case Rank.jack:
        return 'Jacks';
      case Rank.ten:
        return 'Tens';
      case Rank.nine:
        return 'Nines';
      case Rank.eight:
        return 'Eights';
      case Rank.seven:
        return 'Sevens';
      case Rank.six:
        return 'Sixes';
      case Rank.five:
        return 'Fives';
      case Rank.four:
        return 'Fours';
      case Rank.three:
        return 'Threes';
      case Rank.two:
        return 'Twos';
    }
  }

  String get suitName {
    switch (suit) {
      case Suit.clubs:
        return 'clubs';
      case Suit.diamonds:
        return 'diamonds';
      case Suit.hearts:
        return 'hearts';
      case Suit.spades:
        return 'spades';
    }
  }

  String get spoken => '$rankSpoken of $suitName';

  String get rankSpoken {
    switch (rank) {
      case Rank.ace:
        return 'Ace';
      case Rank.king:
        return 'King';
      case Rank.queen:
        return 'Queen';
      case Rank.jack:
        return 'Jack';
      default:
        return rankLabel;
    }
  }

  @override
  bool operator ==(Object other) => other is PlayingCard && other.id == id;

  @override
  int get hashCode => Object.hash(suit, rank);
}

const List<PlayingCard> kSampleHand = [
  PlayingCard(Suit.hearts, Rank.ace),
  PlayingCard(Suit.hearts, Rank.seven),
  PlayingCard(Suit.spades, Rank.king),
  PlayingCard(Suit.hearts, Rank.ten),
  PlayingCard(Suit.diamonds, Rank.ace),
  PlayingCard(Suit.clubs, Rank.four),
  PlayingCard(Suit.spades, Rank.queen),
  PlayingCard(Suit.diamonds, Rank.nine),
  PlayingCard(Suit.clubs, Rank.ace),
  PlayingCard(Suit.diamonds, Rank.seven),
  PlayingCard(Suit.spades, Rank.jack),
  PlayingCard(Suit.clubs, Rank.eight),
  PlayingCard(Suit.spades, Rank.two),
];

int deckPoints() {
  var total = 0;
  for (final suit in Suit.values) {
    for (final rank in Rank.values) {
      total += PlayingCard(suit, rank).points;
    }
  }
  return total;
}
