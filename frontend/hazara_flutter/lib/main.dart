import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'net/room_link.dart';
import 'screens/arrangement_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/hazara_theme.dart';

void main() {
  TableSettings.load();
  runApp(const HazaraApp());
}

class HazaraApp extends StatelessWidget {
  const HazaraApp({super.key, this.showCoach = true, this.preview = false});

  final bool showCoach;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HAZARA',
      debugShowCheckedModeBanner: false,
      theme: hazaraTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: TableSettings.reducedMotion,
          builder: (context, reduce, _) {
            if (!reduce || child == null) return child ?? const SizedBox();
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child,
            );
          },
        );
      },
      home: preview
          ? ArrangementScreen(showCoach: showCoach)
          : HomeScreen(roomCode: roomFromLocation()),
    );
  }
}
