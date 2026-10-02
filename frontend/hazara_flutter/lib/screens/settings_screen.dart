import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/hazara_theme.dart';

class TableSettings {
  static final haptics = ValueNotifier<bool>(true);
  static final reducedMotion = ValueNotifier<bool>(false);
  static final tableSound = ValueNotifier<bool>(true);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    haptics.value = prefs.getBool('hazara_haptics') ?? true;
    reducedMotion.value = prefs.getBool('hazara_motion') ?? false;
    tableSound.value = prefs.getBool('hazara_sound') ?? true;
  }

  static Future<void> setHaptics(bool value) async {
    haptics.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hazara_haptics', value);
  }

  static Future<void> setTableSound(bool value) async {
    tableSound.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hazara_sound', value);
  }

  static Future<void> setReducedMotion(bool value) async {
    reducedMotion.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hazara_motion', value);
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HazaraColors.feltDeep,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ColoredBox(
              color: HazaraColors.felt,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: TableSettings.tableSound,
                    builder: (context, value, _) => SwitchListTile(
                      key: const ValueKey('table-sound'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Table sound'),
                      subtitle: const Text(
                        'Emoji, sounds, and voice play live. Nothing is saved.',
                      ),
                      value: value,
                      onChanged: (next) {
                        TableSettings.setTableSound(next);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<bool>(
                    valueListenable: TableSettings.haptics,
                    builder: (context, value, _) => SwitchListTile(
                      key: const ValueKey('haptics'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Haptics'),
                      subtitle: const Text(
                        'A light tap when you place a card.',
                      ),
                      value: value,
                      onChanged: (value) {
                        TableSettings.setHaptics(value);
                      },
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: TableSettings.reducedMotion,
                    builder: (context, value, _) => SwitchListTile(
                      key: const ValueKey('reduced-motion'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reduced motion'),
                      subtitle: const Text(
                        'Crossfade instead of moving cards. The table still waits the same time.',
                      ),
                      value: value,
                      onChanged: (value) {
                        TableSettings.setReducedMotion(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Card faces stay the standard deck.',
                    style: TextStyle(color: HazaraColors.creamMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
