import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

export '../theme/app_colors.dart';

ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);
  const colorScheme = ColorScheme.light(
    primary: AppColors.primaryAccent,
    secondary: AppColors.secondaryAccent,
    surface: AppColors.surfaceCard,
    error: AppColors.danger,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: AppColors.textPrimary,
    onError: Colors.white,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.primaryBackground,
    canvasColor: AppColors.primaryBackground,
    cardColor: AppColors.surfaceCard,
    colorScheme: colorScheme,
    textTheme: base.textTheme
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          bodySmall: const TextStyle(color: AppColors.textSecondary),
          titleLarge: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryBackground,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dividerColor: AppColors.borderSubtle,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surfaceCard,
      indicatorColor: const Color(0x145b50f6),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryAccent
              : AppColors.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryAccent
              : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryAccent,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primaryAccent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryAccent,
        foregroundColor: Colors.white,
      ),
    ),
  );
}

InputDecoration appInputDecoration(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: AppColors.textSecondary),
  filled: true,
  fillColor: AppColors.surfaceCard,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: AppColors.borderSubtle),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
  ),
);

ButtonStyle secondaryButtonStyle() => OutlinedButton.styleFrom(
  foregroundColor: AppColors.textPrimary,
  side: const BorderSide(color: AppColors.secondaryAccent),
  minimumSize: const Size(0, 52),
);
