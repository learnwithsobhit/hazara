/// Talk blast overlay — emoji and text lines rise from each seat position,
/// similar to Judgement's emoji_blast.dart + cartoon_text_blast.dart.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/hazara_theme.dart';

/// A single in-flight burst (emoji or text) from a given seat.
class TalkBurst {
  TalkBurst({
    required this.id,
    required this.fromSeat,
    required this.text,
    required this.isEmoji,
    required this.created,
    this.ttlMs = 2400,
  });

  final String id;
  final int fromSeat; // 0-3
  final String text;
  final bool isEmoji;
  final DateTime created;
  final int ttlMs;

  bool isExpired() =>
      DateTime.now().difference(created).inMilliseconds > ttlMs;
}

/// Overlay layer that renders all active bursts.
/// Wrap the table stack in this widget.
class TalkBlastOverlay extends StatefulWidget {
  const TalkBlastOverlay({
    super.key,
    required this.bursts,
    required this.child,
  });

  final List<TalkBurst> bursts;
  final Widget child;

  @override
  State<TalkBlastOverlay> createState() => _TalkBlastOverlayState();
}

class _TalkBlastOverlayState extends State<TalkBlastOverlay> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.bursts.isNotEmpty)
          IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    for (final burst in widget.bursts)
                      _BurstWidget(
                        burst: burst,
                        maxWidth: constraints.maxWidth,
                        maxHeight: constraints.maxHeight,
                      ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Computes the anchor point for a given seat (0=you/bottom, 1=left, 2=top, 3=right).
Offset seatAnchor(int seat, double w, double h) {
  switch (seat % 4) {
    case 0: // You — bottom centre
      return Offset(w / 2, h * 0.82);
    case 1: // Left opponent
      return Offset(w * 0.12, h * 0.48);
    case 2: // Top opponent
      return Offset(w / 2, h * 0.14);
    case 3: // Right opponent
      return Offset(w * 0.88, h * 0.48);
    default:
      return Offset(w / 2, h / 2);
  }
}

class _BurstWidget extends StatefulWidget {
  const _BurstWidget({
    required this.burst,
    required this.maxWidth,
    required this.maxHeight,
  });

  final TalkBurst burst;
  final double maxWidth;
  final double maxHeight;

  @override
  State<_BurstWidget> createState() => _BurstWidgetState();
}

class _BurstWidgetState extends State<_BurstWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.burst.ttlMs),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anchor = seatAnchor(
      widget.burst.fromSeat,
      widget.maxWidth,
      widget.maxHeight,
    );
    // Stagger multiple emojis slightly with a pseudo-random spread.
    final jitter = (widget.burst.id.hashCode % 40) - 20.0;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_ctrl.value);
        final opacity = (1 - _ctrl.value * 1.2).clamp(0.0, 1.0);
        final rise = t * 60;
        final scale = widget.burst.isEmoji
            ? 0.7 + t * 0.6
            : 1.0;

        return Positioned(
          left: anchor.dx + jitter - (widget.burst.isEmoji ? 14 : 40),
          top: anchor.dy - rise - (widget.burst.isEmoji ? 14 : 10),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: widget.burst.isEmoji
                  ? Text(
                      widget.burst.text,
                      style: const TextStyle(fontSize: 28),
                    )
                  : _TextBubble(text: widget.burst.text),
            ),
          ),
        );
      },
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HazaraColors.feltDeep.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HazaraColors.gold.withAlpha(80)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: HazaraColors.cream,
          fontSize: 13,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Helper: add a new burst to a mutable list and remove expired ones.
/// Call this in setState to drive the overlay.
void addBurst({
  required List<TalkBurst> bursts,
  required int fromSeat,
  required String text,
  required bool isEmoji,
}) {
  final id = '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}';
  bursts.removeWhere((b) => b.isExpired());
  bursts.add(TalkBurst(
    id: id,
    fromSeat: fromSeat,
    text: text,
    isEmoji: isEmoji,
    created: DateTime.now(),
  ));
}
