/// Flip a card from back to face. Skips motion when reduced-motion is on.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/playing_card.dart';
import '../theme/hazara_theme.dart';
import 'card_back.dart';
import 'card_face.dart';

class FlipRevealCard extends StatefulWidget {
  const FlipRevealCard({
    super.key,
    required this.card,
    required this.width,
    this.dimmed = false,
    this.glow = false,
    this.delay = Duration.zero,
    this.faceUp = true,
  });

  final PlayingCard card;
  final double width;
  final bool dimmed;
  final bool glow;
  final Duration delay;
  final bool faceUp;

  @override
  State<FlipRevealCard> createState() => _FlipRevealCardState();
}

class _FlipRevealCardState extends State<FlipRevealCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _armed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _arm();
  }

  @override
  void didUpdateWidget(FlipRevealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id ||
        oldWidget.faceUp != widget.faceUp) {
      _armed = false;
      _ctrl.value = 0;
      _arm();
    }
  }

  void _arm() {
    if (_armed) return;
    _armed = true;
    if (!widget.faceUp) {
      _ctrl.value = 0;
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      _ctrl.forward(from: 0);
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (mounted) _ctrl.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      return _face();
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final angle = t * math.pi;
        final showFace = t >= 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..rotateY(angle),
          child: showFace
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _face(),
                )
              : CardBack(width: widget.width, height: widget.width * 1.45),
        );
      },
    );
  }

  Widget _face() {
    final face = CardFace(
      card: widget.card,
      width: widget.width,
      selected: widget.glow,
      dimmed: widget.dimmed,
    );
    if (!widget.glow) return face;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: HazaraColors.gold.withAlpha(160),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: face,
    );
  }
}
