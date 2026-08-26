import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primaryBackground = Color(0xfff8fafc);
  static const surfaceCard = Color(0xffffffff);
  static const primaryAccent = Color(0xff5b50f6);
  static const secondaryAccent = Color(0xff2563eb);
  static const successMint = Color(0xff0d9488);
  static const highlightGold = Color(0xffeab308);
  static const textPrimary = Color(0xff0f172a);
  static const textSecondary = Color(0xff64748b);
  static const borderSubtle = Color(0xffe2e8f0);

  static const surfaceRaised = Color(0xffffffff);
  static const border = borderSubtle;
  static const danger = Color(0xffff5252);
  static const coral = Color(0xfff97316);

  // Compatibility aliases keep shared components concise while the visual
  // language is driven by the semantic tokens above.
  static const ink = textPrimary;
  static const charcoal = surfaceCard;
  static const panel = surfaceCard;
  static const cream = textPrimary;
  static const gold = primaryAccent;
  static const goldDark = secondaryAccent;
  static const muted = textSecondary;
  static const sage = successMint;
}
