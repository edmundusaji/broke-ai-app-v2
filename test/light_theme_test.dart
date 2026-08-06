import 'dart:io';

import 'package:broke_ai_app/core/app_assets.dart';
import 'package:broke_ai_app/core/app_theme.dart';
import 'package:broke_ai_app/pages/app_boot_page.dart';
import 'package:broke_ai_app/pages/onboarding_page.dart';
import 'package:broke_ai_app/widgets/mascot_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    expect(File(AppAssets.onboardingInsightsDog).existsSync(), isTrue);
    expect(File(AppAssets.onboardingTrackingDog).existsSync(), isTrue);
    expect(File(AppAssets.onboardingGuestFeature).existsSync(), isTrue);
    expect(File(AppAssets.onboardingInsightsFeature).existsSync(), isTrue);
    expect(File(AppAssets.onboardingTrackingFeature).existsSync(), isTrue);
    expect(File(AppAssets.appIcon).existsSync(), isTrue);
    expect(File(AppAssets.dashboardDog).existsSync(), isTrue);
    expect(File(AppAssets.loginDog).existsSync(), isTrue);
    expect(pubspec, contains('assets/mockups/light_mode/'));
    expect(pubspec, contains('assets/mockups/light_mode/onboarding_features/'));
    expect(pubspec, contains('assets/mockups/light_mode/homepage/'));
    expect(pubspec, contains('assets/mockups/light_mode/profilepage/'));
    expect(pubspec, contains('assets/mockups/light_mode/scanpage/'));
    expect(pubspec, contains('assets/app-icon/icon-2.png'));
    expect(
      File(
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      ).lengthSync(),
      greaterThan(10000),
    );
    expect(
      File(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
        'Icon-App-1024x1024@1x.png',
      ).existsSync(),
      isTrue,
    );
  });

  testWidgets('boot page renders the Broke.AI app icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppBootPage()));

    expect(find.text('BROKE.AI'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == AppAssets.appIcon,
      ),
      findsOneWidget,
    );
  });

  testWidgets('onboarding carousel exposes all three stories', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guest Mode'), findsOneWidget);
    expect(find.bySemanticsLabel('Onboarding page 1 of 3'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Smarter Insights'), findsOneWidget);
    expect(find.bySemanticsLabel('Onboarding page 2 of 3'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Smart Tracking'), findsOneWidget);
    expect(find.bySemanticsLabel('Onboarding page 3 of 3'), findsOneWidget);
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
