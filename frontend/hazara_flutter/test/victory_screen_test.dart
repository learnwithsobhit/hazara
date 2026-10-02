import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazara_flutter/net/snapshot.dart';
import 'package:hazara_flutter/screens/victory_screen.dart';
import 'package:hazara_flutter/theme/hazara_theme.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

TableSnapshot _snapshot({
  required int youSeat,
  required List<int> scores,
}) {
  return TableSnapshot(
    phase: 'summary',
    matchLength: 'short',
    you: youSeat,
    dealNo: 3,
    matchOver: true,
    youAreHost: youSeat == 0,
    locked: true,
    hand: const [],
    seats: [
      SeatView(seat: 0, name: 'Ada', status: 'ready', you: youSeat == 0),
      SeatView(seat: 1, name: 'Bo',  status: 'ready', you: youSeat == 1),
      SeatView(seat: 2, name: 'Cy',  status: 'ready', you: youSeat == 2),
      SeatView(seat: 3, name: 'Di',  status: 'ready', you: youSeat == 3),
    ],
    scores: scores,
    beats: const [],
    note: null,
    arrangeDeadlineMs: 0,
    revealIndex: 0,
    revealUntilMs: 0,
    serverNow: 0,
    protocol: 1,
    autoLocked: false,
    sealed: const [],
    dealer: 0,
  );
}

Widget _wrap(Widget child) => MaterialApp(theme: hazaraTheme(), home: child);

// Set a phone-like canvas for every test so the Podium widget doesn't overflow.
void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

void main() {
  group('VictoryScreen', () {
    testWidgets('shows winner name followed by wins!', (tester) async {
      _bigScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
      // Ada (seat 0) has the highest score.
      final snap = _snapshot(youSeat: 1, scores: [420, 380, 300, 260]);

      await tester.pumpWidget(
        _wrap(VictoryScreen(snap: snap, onRematch: () {}, onHome: () {})),
      );

      expect(find.text('Ada wins!'), findsOneWidget);
    });

    testWidgets('Home button fires onHome callback', (tester) async {
      _bigScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
      final snap = _snapshot(youSeat: 1, scores: [420, 380, 300, 260]);
      bool homeCalled = false;

      await tester.pumpWidget(
        _wrap(VictoryScreen(
          snap: snap,
          onRematch: () {},
          onHome: () => homeCalled = true,
        )),
      );

      await tester.tap(find.text('Home'));
      expect(homeCalled, isTrue);
    });

    testWidgets('host sees Play again button that fires onRematch', (tester) async {
      _bigScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
      // seat 0 (Ada) is host.
      final snap = _snapshot(youSeat: 0, scores: [420, 380, 300, 260]);
      bool rematchCalled = false;

      await tester.pumpWidget(
        _wrap(VictoryScreen(
          snap: snap,
          onRematch: () => rematchCalled = true,
          onHome: () {},
        )),
      );

      expect(find.text('Play again'), findsOneWidget);
      await tester.tap(find.text('Play again'));
      expect(rematchCalled, isTrue);
    });

    testWidgets('non-host sees waiting message, no Play again', (tester) async {
      _bigScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
      // seat 1 (Bo) is not host.
      final snap = _snapshot(youSeat: 1, scores: [420, 380, 300, 260]);

      await tester.pumpWidget(
        _wrap(VictoryScreen(snap: snap, onRematch: () {}, onHome: () {})),
      );

      expect(find.text('Play again'), findsNothing);
      expect(find.text('Waiting for the host to play again.'), findsOneWidget);
    });

    testWidgets('podium renders 🥇 medal for first-place winner', (tester) async {
      _bigScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
      // Cy (seat 2) wins with 420 pts.
      final snap = _snapshot(youSeat: 0, scores: [260, 300, 420, 380]);

      await tester.pumpWidget(
        _wrap(VictoryScreen(snap: snap, onRematch: () {}, onHome: () {})),
      );

      expect(find.text('Cy wins!'), findsOneWidget);
      expect(find.textContaining('🥇'), findsWidgets);
    });

    testWidgets('shows pts-suffixed scores for all four players', (tester) async {
      _bigScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
      final snap = _snapshot(youSeat: 0, scores: [360, 300, 240, 60]);

      await tester.pumpWidget(
        _wrap(VictoryScreen(snap: snap, onRematch: () {}, onHome: () {})),
      );

      expect(find.text('360 pts'), findsOneWidget);
      expect(find.text('300 pts'), findsOneWidget);
      expect(find.text('240 pts'), findsOneWidget);
      expect(find.text('60 pts'),  findsOneWidget);
    });

    testWidgets('highest scorer is always listed first in score rows', (tester) async {
      _bigScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
      // Di (seat 3) has 500 pts — should be ranked first.
      final snap = _snapshot(youSeat: 0, scores: [200, 220, 180, 500]);

      await tester.pumpWidget(
        _wrap(VictoryScreen(snap: snap, onRematch: () {}, onHome: () {})),
      );

      expect(find.text('Di wins!'), findsOneWidget);
      expect(find.text('500 pts'), findsOneWidget);
    });
  });
}
