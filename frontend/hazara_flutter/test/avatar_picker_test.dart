import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazara_flutter/widgets/avatar_picker.dart';
import 'package:hazara_flutter/theme/hazara_theme.dart';

Widget _wrap(Widget child) => MaterialApp(theme: hazaraTheme(), home: child);

void main() {
  group('AvatarChip', () {
    testWidgets('renders a face image', (tester) async {
      await tester.pumpWidget(
        _wrap(const Scaffold(body: AvatarChip(index: 0))),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(Scaffold(body: AvatarChip(index: 2, onTap: () => tapped = true))),
      );
      await tester.tap(find.byType(AvatarChip));
      expect(tapped, isTrue);
    });

    test('pack has 40 illustrated faces', () {
      expect(kAvatarCount, 40);
      expect(avatarAsset(0), 'assets/avatars/face_01.png');
      expect(avatarAsset(39), 'assets/avatars/face_40.png');
      expect(avatarAsset(40), 'assets/avatars/face_01.png');
    });
  });

  group('showAvatarPicker', () {
    testWidgets('opens a grid of face chips', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showAvatarPicker(ctx, 0),
              child: const Text('Open'),
            ),
          ),
        )),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Choose your avatar'), findsOneWidget);
      expect(find.byType(AvatarChip), findsWidgets);
    });

    testWidgets('dismissing bottom sheet returns null', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int? result = -1;
      await tester.pumpWidget(
        _wrap(Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await showAvatarPicker(ctx, 0);
              },
              child: const Text('Open'),
            ),
          ),
        )),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}
