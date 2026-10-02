import 'package:flutter_test/flutter_test.dart';
import 'package:hazara_flutter/engine/classifier.dart';
import 'package:hazara_flutter/engine/hindi.dart';
import 'package:hazara_flutter/model/playing_card.dart';

PlayingCard c(Suit suit, Rank rank) => PlayingCard(suit, rank);

void main() {
  test('a troy of aces is three ikke', () {
    final combo = evaluateSet([
      c(Suit.hearts, Rank.ace),
      c(Suit.diamonds, Rank.ace),
      c(Suit.clubs, Rank.ace),
    ])!;
    expect(hindiCombo(combo), 'ट्रॉय · तीन इक्के');
  });

  test('a suited ace-king-queen is a colour run', () {
    final combo = evaluateSet([
      c(Suit.spades, Rank.ace),
      c(Suit.spades, Rank.king),
      c(Suit.spades, Rank.queen),
    ])!;
    expect(hindiCombo(combo), 'कलर रन · इक्का–बादशाह–रानी · एक रंग');
  });

  test('ace-two-three keeps that order', () {
    final combo = evaluateSet([
      c(Suit.hearts, Rank.ace),
      c(Suit.diamonds, Rank.two),
      c(Suit.clubs, Rank.three),
    ])!;
    expect(hindiCombo(combo), 'रन · इक्का–दुक्की–तीगा');
  });

  test('two-ace-king of one suit is colour', () {
    final combo = evaluateSet([
      c(Suit.hearts, Rank.two),
      c(Suit.hearts, Rank.ace),
      c(Suit.hearts, Rank.king),
    ])!;
    expect(hindiCombo(combo), 'कलर · इक्का–बादशाह–दुक्की · एक रंग');
  });

  test('a pair names the rank', () {
    final combo = evaluateSet([
      c(Suit.hearts, Rank.king),
      c(Suit.spades, Rank.king),
      c(Suit.diamonds, Rank.seven),
    ])!;
    expect(hindiCombo(combo), 'जोड़ी · दो बादशाह');
  });
}
