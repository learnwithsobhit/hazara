import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazara_flutter/model/playing_card.dart';
import 'package:hazara_flutter/net/snapshot.dart';
import 'package:hazara_flutter/theme/hazara_theme.dart';
import 'package:hazara_flutter/widgets/felt_table.dart';
import 'package:hazara_flutter/widgets/reveal_table.dart';

TableSnapshot _revealSnap() {
  return TableSnapshot(
    phase: 'reveal',
    matchLength: 'short',
    you: 0,
    dealNo: 1,
    matchOver: false,
    youAreHost: true,
    locked: true,
    hand: const [],
    seats: [
      SeatView(seat: 0, name: 'Ada', status: 'ready', you: true),
      SeatView(seat: 1, name: 'Bo', status: 'ready', you: false),
      SeatView(seat: 2, name: 'Cy', status: 'ready', you: false),
      SeatView(seat: 3, name: 'Di', status: 'ready', you: false),
    ],
    scores: const [90, 0, 0, 0],
    beats: [
      BeatView(
        winner: 'Ada',
        points: 90,
        tied: false,
        rows: [
          BeatRow(
            name: 'Ada',
            label: 'Troy of Aces',
            cards: [
              PlayingCard.parse('hearts-ace'),
              PlayingCard.parse('spades-ace'),
              PlayingCard.parse('diamonds-ace'),
            ],
            spareId: null,
          ),
          BeatRow(
            name: 'Bo',
            label: 'Pair of Kings',
            cards: [
              PlayingCard.parse('hearts-king'),
              PlayingCard.parse('spades-king'),
            ],
            spareId: null,
          ),
        ],
      ),
    ],
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

Widget _wrap(Widget child) => MaterialApp(
      theme: hazaraTheme(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
        child: child,
      ),
    );

void main() {
  testWidgets('PlayTable seats sit on the oval with names', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        const PlayTable(
          seats: [
            TableSeatInfo(name: 'You', you: true, remainingSets: 3),
            TableSeatInfo(name: 'Bo', remainingSets: 3),
            TableSeatInfo(name: 'Cy', remainingSets: 3),
            TableSeatInfo(name: 'Di', remainingSets: 3),
          ],
        ),
      ),
    );

    expect(find.text('You (you)'), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);
    expect(find.text('Cy'), findsOneWidget);
    expect(find.text('Di'), findsOneWidget);
  });

  testWidgets('RevealTable names the set and the winner', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(RevealTable(snap: _revealSnap(), clockLabel: '0:04')),
    );
    await tester.pump();

    expect(find.textContaining('Strongest'), findsWidgets);
    expect(find.textContaining('takes this set'), findsOneWidget);
    expect(find.textContaining('Ada captures 90'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
