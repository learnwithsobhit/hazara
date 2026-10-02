import 'package:flutter/material.dart';

import '../model/playing_card.dart';

/// Face from the same public-domain PNG deck Judgement uses.
class CardFace extends StatelessWidget {
  const CardFace({
    super.key,
    required this.card,
    required this.width,
    required this.selected,
    this.dimmed = false,
    this.onTap,
    this.cardKey,
  });

  final PlayingCard card;
  final double width;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;
  final Key? cardKey;

  String get _asset => 'assets/cards/${card.rank.name}_${card.suit.name}.png';

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final height = width * 1.45;
    final face = AnimatedContainer(
      duration: Duration(milliseconds: reduce ? 0 : 150),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.08),
        border: Border.all(
          color: selected ? const Color(0xFFFFC857) : Colors.black26,
          width: selected ? 3 : 1,
        ),
        boxShadow: [
          if (selected)
            const BoxShadow(color: Color(0x88FFC857), blurRadius: 12)
          else
            const BoxShadow(
              color: Colors.black38,
              blurRadius: 3,
              offset: Offset(1, 2),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.06),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.white),
            Image.asset(
              _asset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => _CardFallback(card: card),
            ),
            if (dimmed) const ColoredBox(color: Color(0x99B0B0B0)),
          ],
        ),
      ),
    );

    return Semantics(
      label: card.spoken,
      button: onTap != null,
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        key: cardKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedSlide(
          offset: selected ? const Offset(0, -0.1) : Offset.zero,
          duration: Duration(milliseconds: reduce ? 0 : 180),
          curve: Curves.easeOut,
          child: face,
        ),
      ),
    );
  }
}

class _CardFallback extends StatelessWidget {
  const _CardFallback({required this.card});

  final PlayingCard card;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Text(
        card.rankLabel,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}
