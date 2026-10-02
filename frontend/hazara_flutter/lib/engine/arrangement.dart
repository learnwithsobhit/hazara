import '../model/playing_card.dart';
import 'classifier.dart';

const List<String> kSetNames = ['Strongest', 'Second', 'Third', 'Spare'];
const List<int> kSetSizes = [3, 3, 3, 4];

class _Snap {
  _Snap(this.sets, this.tray);

  final List<List<PlayingCard>> sets;
  final List<PlayingCard> tray;
}

class ArrangementModel {
  ArrangementModel({List<PlayingCard>? hand}) {
    reset(hand ?? kSampleHand);
  }

  final List<List<PlayingCard>> sets = List.generate(4, (_) => <PlayingCard>[]);
  final List<PlayingCard> tray = [];
  final List<PlayingCard> selected = [];
  final List<_Snap> _history = [];

  bool locked = false;
  String? lastError;
  int? editingSet;

  void reset([List<PlayingCard>? hand]) {
    _history.clear();
    selected.clear();
    locked = false;
    lastError = null;
    editingSet = null;
    for (final set in sets) {
      set.clear();
    }
    tray
      ..clear()
      ..addAll(hand ?? kSampleHand);
  }

  void unlockPreview() {
    locked = false;
    lastError = null;
  }

  void restoreLocked(List<List<PlayingCard>> placed) {
    final known = {
      for (final card in [...tray, for (final set in sets) ...set])
        card.id: card,
    };
    for (final set in sets) {
      set.clear();
    }
    tray
      ..clear()
      ..addAll(known.values);
    for (var index = 0; index < placed.length && index < sets.length; index++) {
      for (final card in placed[index]) {
        final found = known[card.id];
        if (found == null) continue;
        sets[index].add(found);
        tray.remove(found);
      }
    }
    selected.clear();
    _history.clear();
    editingSet = null;
    lastError = null;
    locked = true;
  }

  bool get canUndo => _history.isNotEmpty && !locked;

  int get placedCount => 13 - tray.length;

  void toggle(PlayingCard card) {
    if (!_editsOpen()) return;
    lastError = null;
    if (selected.contains(card)) {
      selected.remove(card);
    } else {
      selected.add(card);
    }
  }

  void clearSelection() {
    selected.clear();
    lastError = null;
  }

  /// Assigns the current selection, or opens the editor when nothing is selected.
  void activateSet(int index) {
    if (!_editsOpen()) return;
    if (selected.isEmpty) {
      editingSet = index;
      lastError = null;
      return;
    }
    _assign(index);
  }

  void openEditor(int index) {
    if (!_editsOpen()) return;
    editingSet = index;
    lastError = null;
  }

  void closeEditor() {
    editingSet = null;
  }

  void moveToTray(PlayingCard card) {
    if (!_editsOpen()) return;
    if (tray.contains(card)) return;
    _push();
    for (final set in sets) {
      set.remove(card);
    }
    selected.remove(card);
    tray.add(card);
    lastError = null;
  }

  void undo() {
    if (!canUndo) return;
    final snap = _history.removeLast();
    for (var i = 0; i < sets.length; i++) {
      sets[i]
        ..clear()
        ..addAll(snap.sets[i]);
    }
    tray
      ..clear()
      ..addAll(snap.tray);
    selected.clear();
    lastError = null;
  }

  /// Reorders the three 3-card sets. The spare set stays in the last slot.
  void sortSets() {
    if (!_editsOpen()) return;
    final order = [0, 1, 2];
    order.sort((a, b) {
      final left = sets[a].length >= 3 ? evaluateSet(sets[a]) : null;
      final right = sets[b].length >= 3 ? evaluateSet(sets[b]) : null;
      if (left == null && right == null) return a.compareTo(b);
      if (left == null) return 1;
      if (right == null) return -1;
      final strength = compareCombo(right, left);
      if (strength != 0) return strength;
      return a.compareTo(b);
    });
    if (order[0] == 0 && order[1] == 1 && order[2] == 2) return;
    _push();
    final next = order
        .map((index) => List<PlayingCard>.of(sets[index]))
        .toList();
    for (var i = 0; i < 3; i++) {
      sets[i]
        ..clear()
        ..addAll(next[i]);
    }
    lastError = null;
  }

  void swapFirstInversion() {
    final index = firstInversion;
    if (index == null || index == 2 || !_editsOpen()) return;
    _push();
    final left = List<PlayingCard>.of(sets[index]);
    final right = List<PlayingCard>.of(sets[index + 1]);
    sets[index]
      ..clear()
      ..addAll(right);
    sets[index + 1]
      ..clear()
      ..addAll(left);
    lastError = null;
  }

  void dropCard(PlayingCard card, int setIndex) {
    if (!_editsOpen() || sets[setIndex].contains(card)) return;
    selected
      ..clear()
      ..add(card);
    _assign(setIndex);
  }

  int? get firstInversion {
    for (var i = 0; i < 3; i++) {
      final left = evaluateSet(sets[i]);
      final right = evaluateSet(sets[i + 1]);
      if (left == null || right == null) continue;
      if (compareCombo(left, right) < 0) return i;
    }
    return null;
  }

  String? get orderWarning {
    final inversion = firstInversion;
    if (inversion == null) return null;
    if (inversion == 2) {
      return 'Spare is stronger than Third. The spare set has to stay the weakest.';
    }
    return '${kSetNames[inversion + 1]} is stronger than ${kSetNames[inversion]}. Swap them to continue.';
  }

  String? get readyReason {
    if (tray.isNotEmpty || !_sizesExact) return 'Place all 13 cards';
    return orderWarning;
  }

  bool get isLegal => readyReason == null;

  void seal() {
    if (!isLegal || locked) return;
    locked = true;
    selected.clear();
    editingSet = null;
    lastError = null;
  }

  String setStatus(int index) {
    final cards = sets[index];
    final size = kSetSizes[index];
    if (cards.isEmpty) return 'Tap cards, then tap this set';
    if (cards.length < 3) return '${cards.length} of $size';
    return evaluateSet(cards)?.label ?? '${cards.length} of $size';
  }

  bool get _sizesExact {
    for (var i = 0; i < 4; i++) {
      if (sets[i].length != kSetSizes[i]) return false;
    }
    return true;
  }

  bool _editsOpen() {
    if (!locked) return true;
    lastError = 'The table already locked your hand.';
    return false;
  }

  void _assign(int index) {
    final moving = selected
        .where((card) => !sets[index].contains(card))
        .toList();
    if (moving.isEmpty) {
      editingSet = index;
      return;
    }
    if (sets[index].length + moving.length > kSetSizes[index]) {
      lastError = 'That set is full.';
      return;
    }
    _push();
    for (final card in moving) {
      tray.remove(card);
      for (final set in sets) {
        set.remove(card);
      }
      sets[index].add(card);
    }
    selected.clear();
    lastError = null;
  }

  void _push() {
    _history.add(
      _Snap(
        sets.map(List<PlayingCard>.of).toList(),
        List<PlayingCard>.of(tray),
      ),
    );
    if (_history.length > 20) _history.removeAt(0);
  }
}
