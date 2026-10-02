import 'package:flutter/material.dart';

import '../engine/classifier.dart';
import '../engine/hindi.dart';
import '../model/playing_card.dart';
import '../theme/hazara_theme.dart';
import '../widgets/card_face.dart';
import '../widgets/hindi_line.dart';

/// Rules a new player can read before sitting down. Pagat Hazari, rules.v1.
class RulesBook extends StatelessWidget {
  const RulesBook({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        _Section(
          title: 'The idea',
          body:
              'Four friends. One 52-card deck. Each person gets 13 cards and splits them into four sets: 3, 3, 3, and 4. Strongest set on top, weakest at the bottom. You play one set at a time. The stronger set captures the cards, and the points on those cards are the score. Every deal is 360 points.',
        ),
        _Section(
          title: 'Arrange the hand',
          body:
              'Name the sets Strongest, Second, Third, and Spare. Each set must be equal to or stronger than the one below it. The spare has four cards and is judged by its best three. Those three must be your weakest set. The extra card still scores if you win that set. Tap cards, then tap a set. Hold Ready when the hand is finished. There is no clock.',
          hindi: 'सेट के नाम: सबसे मजबूत, दूसरा, तीसरा, चौथा सेट।',
        ),
        _Section(
          title: 'Combinations',
          body:
              'Strongest type first. A higher type always beats a lower type. Inside one type, the higher ranks win.',
        ),
        _Combo(
          name: 'Troy',
          line: 'Three of the same rank. Aces beat kings, down to twos.',
          cards: [
            PlayingCard(Suit.hearts, Rank.ace),
            PlayingCard(Suit.diamonds, Rank.ace),
            PlayingCard(Suit.clubs, Rank.ace),
          ],
        ),
        _Combo(
          name: 'Colour run',
          line:
              'Three in a row, all one suit. Ace–king–queen is best, then ace–2–3, then king–queen–jack, down to 4–3–2.',
          cards: [
            PlayingCard(Suit.spades, Rank.ace),
            PlayingCard(Suit.spades, Rank.king),
            PlayingCard(Suit.spades, Rank.queen),
          ],
        ),
        _Combo(
          name: 'Run',
          line:
              'Three in a row, not all one suit. Same order as a colour run. A colour run of the same ranks is stronger.',
          cards: [
            PlayingCard(Suit.hearts, Rank.ace),
            PlayingCard(Suit.diamonds, Rank.king),
            PlayingCard(Suit.clubs, Rank.queen),
          ],
        ),
        _Combo(
          name: 'Colour',
          line:
              'Three of one suit that are not in a row. Compare the highest card, then the next, then the lowest.',
          cards: [
            PlayingCard(Suit.hearts, Rank.ace),
            PlayingCard(Suit.hearts, Rank.ten),
            PlayingCard(Suit.hearts, Rank.four),
          ],
        ),
        _Combo(
          name: 'Pair',
          line:
              'Two of one rank, plus a side card. Compare the pair first, then the side card.',
          cards: [
            PlayingCard(Suit.hearts, Rank.king),
            PlayingCard(Suit.spades, Rank.king),
            PlayingCard(Suit.diamonds, Rank.seven),
          ],
        ),
        _Combo(
          name: 'Indi',
          line:
              'None of the above. Compare the highest card, then the next, then the lowest.',
          cards: [
            PlayingCard(Suit.hearts, Rank.ace),
            PlayingCard(Suit.diamonds, Rank.nine),
            PlayingCard(Suit.clubs, Rank.four),
          ],
        ),
        _Section(
          title: 'One catch with the ace',
          body:
              'An ace can sit with the king, or with the 2, but not with both. 2–ace–king of one suit is Colour, not a colour run.',
        ),
        _Section(
          title: 'An example',
          body:
              'Ada plays the colour run ace–king–queen of spades. Bo plays ace–king–queen in three suits, a run. Same ranks, but the colour run is the stronger type, so Ada takes all six cards: 60 points.',
        ),
        _ExampleRow(
          name: 'Ada · Colour run',
          cards: [
            PlayingCard(Suit.spades, Rank.ace),
            PlayingCard(Suit.spades, Rank.king),
            PlayingCard(Suit.spades, Rank.queen),
          ],
        ),
        _ExampleRow(
          name: 'Bo · Run',
          cards: [
            PlayingCard(Suit.hearts, Rank.ace),
            PlayingCard(Suit.diamonds, Rank.king),
            PlayingCard(Suit.clubs, Rank.queen),
          ],
        ),
        SizedBox(height: 8),
        _Section(
          title: 'The spare',
          body:
              'A four-card set is compared by its best three cards. The card left out is dimmed when the set is shown. It still scores if that set is captured. Here the best three are a colour, ace–10–4 of hearts. The 7 of clubs is the spare. Winning this set scores 30.',
        ),
        _ExampleRow(
          name: 'Spare · best three, plus one',
          cards: [
            PlayingCard(Suit.hearts, Rank.ace),
            PlayingCard(Suit.hearts, Rank.ten),
            PlayingCard(Suit.hearts, Rank.four),
            PlayingCard(Suit.clubs, Rank.seven),
          ],
          spare: PlayingCard(Suit.clubs, Rank.seven),
        ),
        _Section(
          title: 'Points',
          body:
              'Ace, king, queen, jack, and 10 are 10 points. Every other rank is 5. Strength decides who captures. Points are the cards you capture, not a bonus for the combination.',
        ),
        _Section(
          title: 'Who leads',
          body:
              'The player on the dealer’s right leads the first set. The winner of a set leads the next one. The fourth set is everyone’s spare. If two sets are exactly equal, the player who plays later in that round takes it. Suits do not break that tie.',
        ),
        _Section(
          title: 'The match',
          body:
              'The host picks the length before the first deal. One deal ends after the summary. Short is three deals. Full continues until one person is alone at 1,000 or more. A tie at the top plays another deal.',
        ),
        _Section(
          title: 'Tricks',
          body:
              'Put a troy or a colour run on top. A strong set under a weaker one will not lock.\n\nKeep a suited sequence together. The same three ranks as a colour run lose to that colour run.\n\nPark a low card in the spare beside a ten or a face card. The low card can be the one left out, and the points still count if you win.\n\nA pretty low run can lose to a messy high colour. Look at the points you might give away, not only the name of the set.\n\nWhen you expect someone to copy your set, remember the later player wins a tie. Leading that set can lose it.\n\nSort sets repairs the three-card order and leaves the spare where it is.',
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body, this.hindi});

  final String title;
  final String body;
  final String? hindi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: HazaraColors.gold,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.35)),
          if (hindi != null) ...[
            const SizedBox(height: 4),
            HindiLine(hindi!),
          ],
        ],
      ),
    );
  }
}

class _Combo extends StatelessWidget {
  const _Combo({required this.name, required this.line, required this.cards});

  final String name;
  final String line;
  final List<PlayingCard> cards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (evaluateSet(cards) != null)
            HindiLine(hindiCombo(evaluateSet(cards)!)),
          const SizedBox(height: 6),
          _Faces(cards: cards),
          const SizedBox(height: 6),
          Text(
            line,
            style: const TextStyle(color: HazaraColors.creamMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _ExampleRow extends StatelessWidget {
  const _ExampleRow({required this.name, required this.cards, this.spare});

  final String name;
  final List<PlayingCard> cards;
  final PlayingCard? spare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _Faces(cards: cards, spare: spare),
        ],
      ),
    );
  }
}

class _Faces extends StatelessWidget {
  const _Faces({required this.cards, this.spare});

  final List<PlayingCard> cards;
  final PlayingCard? spare;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final card in cards)
          CardFace(
            card: card,
            width: 52,
            selected: false,
            dimmed: spare != null && spare!.id == card.id,
          ),
      ],
    );
  }
}
