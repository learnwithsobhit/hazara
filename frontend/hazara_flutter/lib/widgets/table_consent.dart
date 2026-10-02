import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../screens/legal/legal_screens.dart';
import '../theme/hazara_theme.dart';

/// Terms and microphone choices shown before Create / Join.
/// Both start checked, matching the Judgement landing defaults the table uses.
class TableConsent extends StatefulWidget {
  const TableConsent({
    super.key,
    required this.legalAccepted,
    required this.allowMic,
    required this.onLegalChanged,
    required this.onMicChanged,
  });

  final bool legalAccepted;
  final bool allowMic;
  final ValueChanged<bool> onLegalChanged;
  final ValueChanged<bool> onMicChanged;

  @override
  State<TableConsent> createState() => _TableConsentState();
}

class _TableConsentState extends State<TableConsent> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
        );
      };
    _privacyTap = TapGestureRecognizer()
      ..onTap = () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
        );
      };
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      color: HazaraColors.gold,
      decoration: TextDecoration.underline,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    const baseStyle = TextStyle(
      color: HazaraColors.cream,
      fontSize: 13,
      height: 1.35,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          key: const ValueKey('terms-checkbox'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: widget.legalAccepted,
          activeColor: HazaraColors.gold,
          checkColor: HazaraColors.ink,
          onChanged: (value) => widget.onLegalChanged(value ?? false),
          title: Text.rich(
            TextSpan(
              style: baseStyle,
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Use',
                  style: linkStyle,
                  recognizer: _termsTap,
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: linkStyle,
                  recognizer: _privacyTap,
                ),
              ],
            ),
          ),
        ),
        CheckboxListTile(
          key: const ValueKey('mic-checkbox'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: widget.allowMic,
          activeColor: HazaraColors.gold,
          checkColor: HazaraColors.ink,
          onChanged: (value) => widget.onMicChanged(value ?? false),
          title: const Text(
            'Allow microphone',
            style: baseStyle,
          ),
          subtitle: const Text(
            'Ask for microphone permission when you create or join a table.',
            style: TextStyle(color: HazaraColors.creamMuted, fontSize: 11, height: 1.3),
          ),
        ),
      ],
    );
  }
}
