import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazara_flutter/main.dart';
import 'package:hazara_flutter/screens/arrangement_screen.dart';
import 'package:hazara_flutter/theme/hazara_theme.dart';

void main() {
  testWidgets('tapping three aces into Strongest names the troy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HazaraApp(preview: true, showCoach: false));
    await tester.pumpAndSettle();

    expect(find.text('Place all 13 cards'), findsOneWidget);
    expect(find.text('HAZARA'), findsOneWidget);

    for (final id in ['hearts-ace', 'diamonds-ace', 'clubs-ace']) {
      await tester.tap(find.byKey(ValueKey('card-$id')));
      await tester.pump();
    }
    expect(find.text('3 selected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('set-0')));
    await tester.pump();

    expect(find.text('Troy of Aces'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back to hand returns a selected card from a set', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HazaraApp(preview: true, showCoach: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('card-hearts-ace')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('set-0')));
    await tester.pump();
    expect(find.text('1 of 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('card-hearts-ace')));
    await tester.pump();
    expect(find.byKey(const ValueKey('back-to-hand')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('back-to-hand')));
    await tester.pump();
    expect(find.text('1 of 3'), findsNothing);
    expect(find.byKey(const ValueKey('back-to-hand')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live arrange hides the table so all four sets stay on screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: hazaraTheme(),
        home: ArrangementScreen(
          showCoach: false,
          live: true,
          banner: 'Deal 1 · One deal',
          seats: const [
            SeatChip(name: 'You', detail: 'Arranging', you: true),
            SeatChip(name: 'Lalu', detail: 'Arranging'),
            SeatChip(name: 'ashish', detail: 'Arranging'),
            SeatChip(name: 'Dharmen', detail: 'Arranging'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Show table'), findsOneWidget);
    expect(find.text('Hide table'), findsNothing);
    expect(find.text('Strongest'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Third'), findsOneWidget);
    expect(find.text('Spare'), findsOneWidget);
    expect(find.text('Your cards'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toggle-table')));
    await tester.pumpAndSettle();

    expect(find.text('Hide table'), findsOneWidget);
    expect(find.text('Show table'), findsNothing);
    expect(find.text('Your cards'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
