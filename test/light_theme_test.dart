import 'dart:io';

import 'package:broke_ai_app/core/app_assets.dart';
import 'package:broke_ai_app/core/app_theme.dart';
import 'package:broke_ai_app/widgets/mascot_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme uses the requested semantic color palette', () {
    final theme = buildAppTheme();

    expect(theme.brightness, Brightness.light);
    expect(AppColors.primaryBackground, const Color(0xfff8fafc));
    expect(AppColors.surfaceCard, const Color(0xffffffff));
    expect(AppColors.primaryAccent, const Color(0xff5b50f6));
    expect(AppColors.secondaryAccent, const Color(0xff2563eb));
    expect(AppColors.successMint, const Color(0xff0d9488));
    expect(AppColors.highlightGold, const Color(0xffeab308));
    expect(AppColors.textPrimary, const Color(0xff0f172a));
    expect(AppColors.textSecondary, const Color(0xff64748b));
    expect(AppColors.borderSubtle, const Color(0xffe2e8f0));
  });

  test('all copied mockups and dog assets are registered', () {
    final dogAssets = Directory('assets/mockups/light_mode')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('-dog.png'))
        .toList();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(dogAssets, hasLength(10));
    expect(File(AppAssets.onboardingDog).existsSync(), isTrue);
    expect(File(AppAssets.dashboardDog).existsSync(), isTrue);
    expect(File(AppAssets.loginDog).existsSync(), isTrue);
    expect(pubspec, contains('assets/mockups/light_mode/'));
    expect(pubspec, contains('assets/mockups/light_mode/homepage/'));
    expect(pubspec, contains('assets/mockups/light_mode/profilepage/'));
    expect(pubspec, contains('assets/mockups/light_mode/scanpage/'));
  });

  testWidgets('mascot image shows a fallback when an asset is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MascotImage(asset: 'assets/missing-dog.png', height: 180),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
  });
}
