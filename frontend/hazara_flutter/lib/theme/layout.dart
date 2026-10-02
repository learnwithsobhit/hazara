/// Responsive layout helpers.
library;

import 'package:flutter/material.dart';

/// Max content width for the main panel. Widens on tablet / desktop.
double tableMaxWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 900) return 620;
  if (width >= 600) return 540;
  return 480;
}

/// Whether the current screen is wide enough to be considered tablet or desktop.
bool isWide(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= 600;
}

/// Padding for the main panel.  Grows slightly on wide screens.
EdgeInsets panelPadding(BuildContext context) {
  if (isWide(context)) {
    return const EdgeInsets.fromLTRB(28, 24, 28, 28);
  }
  return const EdgeInsets.fromLTRB(20, 16, 20, 20);
}
