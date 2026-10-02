import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazara_flutter/screens/home_screen.dart';
import 'package:hazara_flutter/theme/hazara_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('the landing page scrolls to the rulebook', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: hazaraTheme(), home: const HomeScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('how-to-play')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('how-to-play')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Troy'), 200);
    expect(find.text('Ada · Colour run'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tricks'), 400);
    expect(find.textContaining('later player wins a tie'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
