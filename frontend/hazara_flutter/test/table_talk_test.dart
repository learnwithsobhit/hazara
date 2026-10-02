import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazara_flutter/widgets/table_talk.dart';

void main() {
  testWidgets('the talk bar shows a live line and a reaction', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableTalkBar(
            lines: const ['Ada  nice 👏'],
            recording: false,
            onEmoji: (_) {},
            onText: (_) {},
            onSound: (_) {},
            onVoice: () {},
          ),
        ),
      ),
    );
    expect(find.text('Ada  nice 👏'), findsOneWidget);
    expect(find.text('🃏'), findsOneWidget);
  });
}
