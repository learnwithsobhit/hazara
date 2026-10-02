import 'package:flutter/material.dart';

import '../theme/hazara_theme.dart';

const talkEmojis = [
  '🔥',
  '😂',
  '👏',
  '😱',
  '😎',
  '💀',
  '🎯',
  '🙌',
  '😤',
  '👀',
  '💪',
  '✨',
  '🃏',
  '👑',
  '💚',
  '😅',
];

const talkSounds = [
  ('laugh', 'Laugh'),
  ('clap', 'Clap'),
  ('oh_no', 'Oh no'),
  ('nice', 'Nice'),
  ('gg', 'GG'),
  ('airhorn', 'Horn'),
  ('facepalm', 'Facepalm'),
];

class TableTalkBar extends StatefulWidget {
  const TableTalkBar({
    super.key,
    required this.lines,
    required this.recording,
    required this.onEmoji,
    required this.onText,
    required this.onSound,
    required this.onVoice,
  });

  final List<String> lines;
  final bool recording;
  final void Function(String emoji) onEmoji;
  final void Function(String text) onText;
  final void Function(String sound) onSound;
  final VoidCallback onVoice;

  @override
  State<TableTalkBar> createState() => _TableTalkBarState();
}

class _TableTalkBarState extends State<TableTalkBar> {
  final _text = TextEditingController();
  bool _more = false;
  bool _sounds = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HazaraColors.feltDeep,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.lines.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in widget.lines)
                      Text(line, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final emoji in talkEmojis)
                    IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => widget.onEmoji(emoji),
                      icon: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  IconButton(
                    tooltip: 'Sounds',
                    onPressed: () => setState(() {
                      _sounds = !_sounds;
                      if (_sounds) _more = false;
                    }),
                    icon: Icon(
                      _sounds ? Icons.music_off : Icons.music_note,
                      color: HazaraColors.gold,
                    ),
                  ),
                  IconButton(
                    tooltip: widget.recording ? 'Send voice' : 'Voice note',
                    onPressed: widget.onVoice,
                    icon: Icon(
                      widget.recording ? Icons.stop_circle : Icons.mic_none,
                      color: widget.recording
                          ? const Color(0xFFE07A5F)
                          : HazaraColors.cream,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Write a line',
                    onPressed: () => setState(() {
                      _more = !_more;
                      if (_more) _sounds = false;
                    }),
                    icon: Icon(
                      _more ? Icons.keyboard_hide : Icons.chat_bubble_outline,
                      color: HazaraColors.cream,
                    ),
                  ),
                ],
              ),
            ),
            if (_sounds)
              Wrap(
                spacing: 6,
                children: [
                  for (final sound in talkSounds)
                    ActionChip(
                      label: Text(sound.$2),
                      onPressed: () => widget.onSound(sound.$1),
                    ),
                ],
              ),
            if (_more)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        hintText: 'A short line. Nothing is saved.',
                        counterText: '',
                        isDense: true,
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    onPressed: () => _send(_text.text),
                    icon: const Icon(Icons.send, color: HazaraColors.gold),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _send(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    widget.onText(text);
    _text.clear();
  }
}
