import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazara_flutter/screens/home_screen.dart';
import 'package:hazara_flutter/screens/lobby_screen.dart';
import 'package:hazara_flutter/theme/hazara_theme.dart';
import 'package:hazara_flutter/util/social_share.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('invite copy is the join URL only', () {
    final text = inviteText('ashish', 'EEDAZ5');
    expect(text, contains('room=EEDAZ5'));
    expect(text, isNot(contains('invited you')));
    expect(text, isNot(contains('Code:')));
  });

  testWidgets('invite link home hides create and extra play options', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: hazaraTheme(),
        home: const HomeScreen(roomCode: 'EEDAZ5'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You\'re invited'), findsOneWidget);
    expect(find.text('EEDAZ5'), findsOneWidget);
    expect(find.text('Join table'), findsOneWidget);
    expect(find.text('Create table'), findsNothing);
    expect(find.text('Create & invite'), findsNothing);
    expect(find.text('Return to your table'), findsNothing);
    expect(find.text('Play online · Soon'), findsNothing);
    expect(find.text('Try the cards on this device'), findsNothing);
    expect(find.text('How to play'), findsNothing);
  });

  testWidgets('invite landing does not inherit the host name', (tester) async {
    SharedPreferences.setMockInitialValues({
      'hazara_token': 'tok',
      'hazara_player': 'pid',
      'hazara_name': 'ashish',
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: hazaraTheme(),
        home: const HomeScreen(roomCode: 'EEDAZ5'),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(const ValueKey('name')));
    expect(field.controller!.text, isEmpty);
    expect(find.text('ashish'), findsNothing);
  });

  testWidgets('create lobby has no join field', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: hazaraTheme(),
        home: const LobbyScreen(name: 'Ada'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('create-room')), findsOneWidget);
    expect(find.text('Match length'), findsOneWidget);
    expect(find.byKey(const ValueKey('join-room')), findsNothing);
    expect(find.text('or join with a code'), findsNothing);
  });

  testWidgets('join lobby has no create options', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: hazaraTheme(),
        home: const LobbyScreen(name: 'ashish', roomCode: 'EEDAZ5'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('join-room')), findsOneWidget);
    expect(find.byKey(const ValueKey('create-room')), findsNothing);
    expect(find.text('Match length'), findsNothing);
    expect(find.text('One deal'), findsNothing);
  });
}
