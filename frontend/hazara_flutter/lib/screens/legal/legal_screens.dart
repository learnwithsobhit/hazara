import 'package:flutter/material.dart';

import '../../theme/hazara_theme.dart';
import '../../util/legal_consent.dart';
import '../../util/legal_copy.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocScaffold(
      title: 'Terms of Use',
      bodySelector: _Doc.terms,
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocScaffold(
      title: 'Privacy Policy',
      bodySelector: _Doc.privacy,
    );
  }
}

enum _Doc { terms, privacy }

class _LegalDocScaffold extends StatelessWidget {
  final String title;
  final _Doc bodySelector;

  const _LegalDocScaffold({required this.title, required this.bodySelector});

  @override
  Widget build(BuildContext context) {
    final body = bodySelector == _Doc.terms ? termsOfUseBody() : privacyPolicyBody();
    return Scaffold(
      backgroundColor: HazaraColors.feltDeep,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: HazaraColors.cream,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                'Agreement version $kLegalAgreementVersion',
                style: const TextStyle(
                  color: HazaraColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                body.trim(),
                style: const TextStyle(
                  height: 1.45,
                  color: HazaraColors.cream,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
