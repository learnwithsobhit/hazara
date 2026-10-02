import 'package:flutter_test/flutter_test.dart';
import 'package:hazara_flutter/engine/arrangement.dart';
import 'package:hazara_flutter/model/playing_card.dart';

PlayingCard c(Suit suit, Rank rank) => PlayingCard(suit, rank);

void put(ArrangementModel model, List<PlayingCard> cards, int set) {
  for (final card in cards) {
    model.toggle(card);
  }
  model.activateSet(set);
}

void main() {
  const troy = [
    PlayingCard(Suit.hearts, Rank.ace),
    PlayingCard(Suit.diamonds, Rank.ace),
    PlayingCard(Suit.clubs, Rank.ace),
  ];
  const colourRun = [
    PlayingCard(Suit.spades, Rank.king),
    PlayingCard(Suit.spades, Rank.queen),
    PlayingCard(Suit.spades, Rank.jack),
  ];
  const run = [
    PlayingCard(Suit.hearts, Rank.ten),
    PlayingCard(Suit.diamonds, Rank.nine),
    PlayingCard(Suit.clubs, Rank.eight),
  ];
  const spare = [
    PlayingCard(Suit.hearts, Rank.seven),
    PlayingCard(Suit.diamonds, Rank.seven),
    PlayingCard(Suit.clubs, Rank.four),
    PlayingCard(Suit.spades, Rank.two),
  ];

  test('a fourth card does not fit in a three-card set', () {
    final model = ArrangementModel();
    put(model, troy, 0);
    model.toggle(c(Suit.spades, Rank.king));
    model.activateSet(0);
    expect(model.lastError, 'That set is full.');
    expect(model.sets[0], troy);
  });

  test('undo puts a card back in the tray', () {
    final model = ArrangementModel();
    put(model, [troy.first], 0);
    expect(model.tray.length, 12);
    model.undo();
    expect(model.tray.length, 13);
    expect(model.sets[0], isEmpty);
  });

  test('the sample hand is legal in descending sets', () {
    final model = ArrangementModel();
    put(model, troy, 0);
    put(model, colourRun, 1);
    put(model, run, 2);
    put(model, spare, 3);
    expect(model.readyReason, isNull);
    model.seal();
    model.toggle(troy.first);
    expect(model.lastError, 'The table already locked your hand.');
  });

  test('sort repairs the three-card sets and leaves the spare in place', () {
    final model = ArrangementModel();
    put(model, run, 0);
    put(model, troy, 1);
    put(model, colourRun, 2);
    put(model, spare, 3);
    expect(model.readyReason, contains('Swap them'));
    model.sortSets();
    expect(model.sets[0], troy);
    expect(model.sets[3], spare);
    expect(model.readyReason, isNull);
  });

  test(
    'a strong spare set is named and is not swapped into a three-card slot',
    () {
      final model = ArrangementModel();
      put(model, colourRun, 0);
      put(model, run, 1);
      put(model, [
        c(Suit.hearts, Rank.seven),
        c(Suit.diamonds, Rank.seven),
        c(Suit.clubs, Rank.four),
      ], 2);
      put(model, [...troy, c(Suit.spades, Rank.two)], 3);
      expect(model.orderWarning, contains('Spare is stronger'));
      final before = List<PlayingCard>.of(model.sets[3]);
      model.swapFirstInversion();
      expect(model.sets[3], before);
    },
  );
}
