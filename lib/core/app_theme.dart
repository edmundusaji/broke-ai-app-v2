import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xff111111);
  static const charcoal = Color(0xff1d1c19);
  static const panel = Color(0xff292720);
  static const cream = Color(0xfffff7e8);
  static const gold = Color(0xffe3b341);
  static const goldDark = Color(0xffa36d10);
  static const muted = Color(0xffaaa69c);
  static const sage = Color(0xff8faa84);
  static const coral = Color(0xffd9785d);
  static const danger = Color(0xffff5252);
}

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.ink,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.gold,
    brightness: Brightness.dark,
  ),
  fontFamily: 'sans',
);

InputDecoration appInputDecoration(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: AppColors.muted),
  filled: true,
  fillColor: AppColors.panel,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: Color(0xff3d3930)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
  ),
);

ButtonStyle secondaryButtonStyle() => OutlinedButton.styleFrom(
  foregroundColor: AppColors.cream,
  side: const BorderSide(color: Color(0xff4c473d)),
  minimumSize: const Size(0, 52),
);
