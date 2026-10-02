import '../model/playing_card.dart';

enum ComboKind { indi, pair, colour, run, colourRun, troy }

class Combo {
  const Combo({
    required this.kind,
    required this.key,
    required this.label,
    required this.counting,
    this.spare,
  });

  final ComboKind kind;
  final List<int> key;
  final String label;
  final List<PlayingCard> counting;
  final PlayingCard? spare;

  bool containsCard(PlayingCard card) =>
      counting.any((candidate) => candidate == card);
}

/// Positive when [a] is stronger than [b]. Zero when they are equal.
int compareCombo(Combo a, Combo b) {
  final kindOrder = a.kind.index.compareTo(b.kind.index);
  if (kindOrder != 0) return kindOrder;
  final length = a.key.length < b.key.length ? a.key.length : b.key.length;
  for (var i = 0; i < length; i++) {
    final keyOrder = a.key[i].compareTo(b.key[i]);
    if (keyOrder != 0) return keyOrder;
  }
  return a.key.length.compareTo(b.key.length);
}

Combo? evaluateSet(List<PlayingCard> cards) {
  if (cards.length < 3) return null;
  if (cards.length == 3) return _classify(cards);
  return _bestOfFour(cards);
}

Combo _bestOfFour(List<PlayingCard> cards) {
  Combo? best;
  String? bestTie;
  for (final subset in _subsetsOfThree(cards)) {
    final combo = _classify(subset);
    final tie = _tieId(subset);
    final replaces =
        best == null ||
        compareCombo(combo, best) > 0 ||
        (compareCombo(combo, best) == 0 && tie.compareTo(bestTie!) < 0);
    if (replaces) {
      best = combo;
      bestTie = tie;
    }
  }
  final chosen = best!;
  final spare = cards.firstWhere((card) => !chosen.containsCard(card));
  return Combo(
    kind: chosen.kind,
    key: chosen.key,
    label: chosen.label,
    counting: chosen.counting,
    spare: spare,
  );
}

Combo _classify(List<PlayingCard> cards) {
  final run = _runKey(cards);
  final suited = cards.every((card) => card.suit == cards.first.suit);
  if (run != null && suited) {
    return Combo(
      kind: ComboKind.colourRun,
      key: [run],
      label: 'Colour Run: ${_runLabel(cards)}',
      counting: cards,
    );
  }
  if (run != null) {
    return Combo(
      kind: ComboKind.run,
      key: [run],
      label: 'Run: ${_runLabel(cards)}',
      counting: cards,
    );
  }
  final counts = <Rank, int>{};
  for (final card in cards) {
    counts[card.rank] = (counts[card.rank] ?? 0) + 1;
  }
  if (counts.length == 1) {
    return Combo(
      kind: ComboKind.troy,
      key: [cards.first.aceHigh],
      label: 'Troy of ${cards.first.rankPlural}',
      counting: cards,
    );
  }
  if (suited) {
    final ordered = _highToLow(cards);
    return Combo(
      kind: ComboKind.colour,
      key: ordered.map((card) => card.aceHigh).toList(),
      label: 'Colour: ${_joined(ordered)}',
      counting: cards,
    );
  }
  if (counts.length == 2) {
    final pairRank = counts.entries.firstWhere((entry) => entry.value == 2).key;
    final kicker = cards.firstWhere((card) => card.rank != pairRank);
    final pairCard = cards.firstWhere((card) => card.rank == pairRank);
    return Combo(
      kind: ComboKind.pair,
      key: [pairCard.aceHigh, kicker.aceHigh],
      label: 'Pair of ${pairCard.rankPlural}',
      counting: cards,
    );
  }
  final ordered = _highToLow(cards);
  return Combo(
    kind: ComboKind.indi,
    key: ordered.map((card) => card.aceHigh).toList(),
    label: 'Indi: ${_joined(ordered)}',
    counting: cards,
  );
}

/// A–K–Q is 15, A–2–3 is 14, K–Q–J is 13, down to 4–3–2 as 4.
int? _runKey(List<PlayingCard> cards) {
  final highs = cards.map((card) => card.aceHigh).toSet();
  if (highs.length != 3) return null;
  final sorted = highs.toList()..sort((a, b) => b.compareTo(a));
  if (sorted[0] == 14 && sorted[1] == 3 && sorted[2] == 2) return 14;
  final consecutive = sorted[0] == sorted[1] + 1 && sorted[1] == sorted[2] + 1;
  if (!consecutive) return null;
  if (sorted[0] == 14) return 15;
  return sorted[0];
}

String _runLabel(List<PlayingCard> cards) {
  final highs = cards.map((card) => card.aceHigh).toSet();
  if (highs.contains(14) && highs.contains(2) && highs.contains(3)) {
    final ace = cards.firstWhere((card) => card.rank == Rank.ace);
    final two = cards.firstWhere((card) => card.rank == Rank.two);
    final three = cards.firstWhere((card) => card.rank == Rank.three);
    return '${ace.rankLabel}\u2013${two.rankLabel}\u2013${three.rankLabel}';
  }
  return _joined(_highToLow(cards));
}

List<PlayingCard> _highToLow(List<PlayingCard> cards) {
  final copy = List<PlayingCard>.of(cards);
  copy.sort((a, b) => b.aceHigh.compareTo(a.aceHigh));
  return copy;
}

String _joined(List<PlayingCard> cards) =>
    cards.map((card) => card.rankLabel).join('\u2013');

String _tieId(List<PlayingCard> cards) {
  final ids = cards.map((card) => card.id).toList()..sort();
  return ids.join('|');
}

List<List<PlayingCard>> _subsetsOfThree(List<PlayingCard> cards) {
  final subsets = <List<PlayingCard>>[];
  for (var i = 0; i < cards.length; i++) {
    for (var j = i + 1; j < cards.length; j++) {
      for (var k = j + 1; k < cards.length; k++) {
        subsets.add([cards[i], cards[j], cards[k]]);
      }
    }
  }
  return subsets;
}
