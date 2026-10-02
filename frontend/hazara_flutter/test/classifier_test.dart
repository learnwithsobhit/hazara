import 'package:flutter_test/flutter_test.dart';
import 'package:hazara_flutter/engine/classifier.dart';
import 'package:hazara_flutter/model/playing_card.dart';

PlayingCard c(Suit suit, Rank rank) => PlayingCard(suit, rank);

void main() {
  test('a full deck is worth 360 points', () {
    expect(deckPoints(), 360);
  });

  test('troy beats a colour run', () {
    final troy = evaluateSet([
      c(Suit.hearts, Rank.ace),
      c(Suit.diamonds, Rank.ace),
      c(Suit.clubs, Rank.ace),
    ])!;
    final colourRun = evaluateSet([
      c(Suit.spades, Rank.ace),
      c(Suit.spades, Rank.king),
      c(Suit.spades, Rank.queen),
    ])!;
    expect(troy.kind, ComboKind.troy);
    expect(troy.label, 'Troy of Aces');
    expect(compareCombo(troy, colourRun), greaterThan(0));
  });

  test(
    'colour runs rank ace-king-queen, then ace-two-three, then king-queen-jack',
    () {
      final akq = evaluateSet([
        c(Suit.spades, Rank.ace),
        c(Suit.spades, Rank.king),
        c(Suit.spades, Rank.queen),
      ])!;
      final a23 = evaluateSet([
        c(Suit.hearts, Rank.ace),
        c(Suit.hearts, Rank.two),
        c(Suit.hearts, Rank.three),
      ])!;
      final kqj = evaluateSet([
        c(Suit.diamonds, Rank.king),
        c(Suit.diamonds, Rank.queen),
        c(Suit.diamonds, Rank.jack),
      ])!;
      expect(akq.label, 'Colour Run: A\u2013K\u2013Q');
      expect(a23.label, 'Colour Run: A\u20132\u20133');
      expect(compareCombo(akq, a23), greaterThan(0));
      expect(compareCombo(a23, kqj), greaterThan(0));
    },
  );

  test('two-ace-king of one suit is colour, not a run', () {
    final around = evaluateSet([
      c(Suit.spades, Rank.two),
      c(Suit.spades, Rank.ace),
      c(Suit.spades, Rank.king),
    ])!;
    final ak3 = evaluateSet([
      c(Suit.hearts, Rank.ace),
      c(Suit.hearts, Rank.king),
      c(Suit.hearts, Rank.three),
    ])!;
    final aqj = evaluateSet([
      c(Suit.diamonds, Rank.ace),
      c(Suit.diamonds, Rank.queen),
      c(Suit.diamonds, Rank.jack),
    ])!;
    expect(around.kind, ComboKind.colour);
    expect(around.label.startsWith('Colour:'), isTrue);
    expect(compareCombo(ak3, around), greaterThan(0));
    expect(compareCombo(around, aqj), greaterThan(0));
  });

  test('equal runs compare equal', () {
    final left = evaluateSet([
      c(Suit.hearts, Rank.seven),
      c(Suit.clubs, Rank.six),
      c(Suit.diamonds, Rank.five),
    ])!;
    final right = evaluateSet([
      c(Suit.spades, Rank.seven),
      c(Suit.diamonds, Rank.six),
      c(Suit.clubs, Rank.five),
    ])!;
    expect(left.kind, ComboKind.run);
    expect(compareCombo(left, right), 0);
  });

  test('colour compares the second card when the first matches', () {
    final higher = evaluateSet([
      c(Suit.hearts, Rank.jack),
      c(Suit.hearts, Rank.nine),
      c(Suit.hearts, Rank.two),
    ])!;
    final lower = evaluateSet([
      c(Suit.spades, Rank.jack),
      c(Suit.spades, Rank.eight),
      c(Suit.spades, Rank.seven),
    ])!;
    expect(higher.kind, ComboKind.colour);
    expect(compareCombo(higher, lower), greaterThan(0));
  });

  test('the spare card is the one left out of the best trio', () {
    final combo = evaluateSet([
      c(Suit.hearts, Rank.seven),
      c(Suit.diamonds, Rank.seven),
      c(Suit.clubs, Rank.four),
      c(Suit.spades, Rank.two),
    ])!;
    expect(combo.label, 'Pair of Sevens');
    expect(combo.spare, c(Suit.spades, Rank.two));
  });
}
