import 'package:flutter/material.dart';

import '../theme/hazara_theme.dart';

/// Devanagari line. Georgia has no Hindi glyphs, so this uses Noto Sans.
class HindiLine extends StatelessWidget {
  const HindiLine(
    this.text, {
    super.key,
    this.size = 13,
    this.color = HazaraColors.gold,
  });

  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'NotoSansDevanagari',
        fontSize: size,
        height: 1.35,
        color: color,
      ),
    );
  }
}
