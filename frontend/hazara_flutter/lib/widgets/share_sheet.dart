/// HAZARA share bottom sheet — WhatsApp, Telegram, X, Web Share, Copy + QR code.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/hazara_theme.dart';
import '../util/social_share.dart';

/// Show the share sheet. Pass [code] for a room invite (QR + link).
/// Pass [customText] to override the body (used for match results).
Future<void> showHazaraShareSheet({
  required BuildContext context,
  String code = '',
  String hostName = '',
  String? customText,
}) {
  final url = code.isEmpty ? (kIsWeb ? Uri.base.origin : 'https://hazara.app') : roomUrl(code);
  final text = customText ?? inviteText(hostName, code);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: HazaraColors.feltDeep,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ShareSheetBody(
      code: code,
      url: url,
      text: text,
    ),
  );
}

class _ShareSheetBody extends StatefulWidget {
  const _ShareSheetBody({
    required this.code,
    required this.url,
    required this.text,
  });
  final String code;
  final String url;
  final String text;

  @override
  State<_ShareSheetBody> createState() => _ShareSheetBodyState();
}

class _ShareSheetBodyState extends State<_ShareSheetBody> {
  String? _toast;

  Future<void> _channel(ShareChannel channel) async {
    final ok = await shareToChannel(
      channel: channel,
      text: widget.text,
      url: widget.url,
    );
    if (!mounted) return;
    setState(() {
      _toast = switch (channel) {
        ShareChannel.copy => ok ? 'Copied!' : 'Could not copy — try long-pressing the code.',
        ShareChannel.system => ok ? 'Shared!' : 'Copied to clipboard.',
        _ => ok ? null : 'Copied — paste into the app.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title row
            Text(
              widget.code.isEmpty ? 'Share result' : 'Invite friends',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: HazaraColors.cream,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.code.isEmpty
                  ? 'Send the final scores to the table'
                  : 'Copy the link or scan the QR · ${widget.code}',
              style: const TextStyle(color: HazaraColors.creamMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),

            if (widget.code.isNotEmpty) ...[
            // QR code centred
            Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  data: widget.url,
                  version: QrVersions.auto,
                  size: 160,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: HazaraColors.ink,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: HazaraColors.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ],

            // Share channel chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(Icons.chat, 'WhatsApp',
                    () => _channel(ShareChannel.whatsapp)),
                _chip(Icons.send, 'Telegram',
                    () => _channel(ShareChannel.telegram)),
                _chip(Icons.alternate_email, 'X',
                    () => _channel(ShareChannel.x)),
                _chip(Icons.ios_share, 'More',
                    () => _channel(ShareChannel.system)),
                _chip(Icons.copy, 'Copy link',
                    () => _channel(ShareChannel.copy)),
              ],
            ),

            if (_toast != null) ...[
              const SizedBox(height: 12),
              Text(
                _toast!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: HazaraColors.gold, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: HazaraColors.gold),
      label: Text(
        label,
        style: const TextStyle(color: HazaraColors.cream),
      ),
      onPressed: onTap,
      backgroundColor: HazaraColors.feltRaised,
      side: const BorderSide(color: HazaraColors.line),
    );
  }
}
