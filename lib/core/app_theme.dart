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
    onSurfaceVariant: AppColors.textSecondary,
    onError: Colors.white,
    outline: Color(0xffcbd5e1),
    outlineVariant: AppColors.borderSubtle,
    surfaceContainerHighest: AppColors.surfaceRaised,
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

ThemeData buildDarkAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  const colorScheme = ColorScheme.dark(
    primary: Color(0xff918bff),
    secondary: Color(0xff60a5fa),
    surface: Color(0xff121a2b),
    surfaceContainerHighest: Color(0xff1a2438),
    error: Color(0xffff7676),
    onPrimary: Color(0xff0b1020),
    onSecondary: Color(0xff0b1020),
    onSurface: Color(0xfff8fafc),
    onSurfaceVariant: Color(0xff9eacc2),
    onError: Color(0xff0b1020),
    outline: Color(0xff40506b),
    outlineVariant: Color(0xff26354d),
  );
  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xff0b1020),
    canvasColor: const Color(0xff0b1020),
    cardColor: colorScheme.surface,
    colorScheme: colorScheme,
    textTheme: base.textTheme
        .apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        )
        .copyWith(
          bodySmall: const TextStyle(color: Color(0xff9eacc2)),
          titleLarge: const TextStyle(
            color: Color(0xfff8fafc),
            fontWeight: FontWeight.w800,
          ),
          titleMedium: const TextStyle(
            color: Color(0xfff8fafc),
            fontWeight: FontWeight.w700,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xff0b1020),
      foregroundColor: Color(0xfff8fafc),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    dividerColor: colorScheme.outlineVariant,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: const Color(0xff292454),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colorScheme.onPrimary
            : colorScheme.onSurfaceVariant,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xff202b40),
      contentTextStyle: TextStyle(color: Color(0xfff8fafc)),
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
