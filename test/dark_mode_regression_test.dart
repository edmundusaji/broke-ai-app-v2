import 'package:broke_ai_app/core/app_assets.dart';
import 'package:broke_ai_app/core/app_theme.dart';
import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/pages/scan_page.dart';
import 'package:broke_ai_app/payment_method_picker.dart';
import 'package:broke_ai_app/providers/app_providers.dart';
import 'package:broke_ai_app/widgets/manual_transaction_sheet.dart';
import 'package:broke_ai_app/widgets/mascot_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final darkTheme = buildDarkAppTheme();
  final darkColors = darkTheme.colorScheme;

  testWidgets('empty-state mascot uses its dark asset and themed surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: const Scaffold(
          body: MascotImage(
            key: ValueKey('dark-mascot'),
            asset: AppAssets.dashboardDog,
            darkAsset: AppAssets.dashboardDogDark,
            height: 180,
          ),
        ),
      ),
    );

    final mascot = find.byKey(const ValueKey('dark-mascot'));
    final image = tester.widget<Image>(
      find.descendant(of: mascot, matching: find.byType(Image)),
    );
    final background = tester.widget<ColoredBox>(
      find.descendant(of: mascot, matching: find.byType(ColoredBox)),
    );

    expect((image.image as AssetImage).assetName, AppAssets.dashboardDogDark);
    expect(background.color, darkColors.surfaceContainerHighest);
  });

  testWidgets('category footer follows the dark color scheme', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: darkTheme,
          home: const Scaffold(body: ManualTransactionSheet()),
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('manual-category-field')),
    );
    await tester.tap(find.byKey(const ValueKey('manual-category-field')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('More categories coming soon!'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    final themedFooter = find.ancestor(
      of: find.text('More categories coming soon!'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color ==
                darkColors.primary.withValues(alpha: .1),
      ),
    );
    expect(themedFooter, findsOneWidget);
  });

  testWidgets('payment picker uses dark surfaces', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: const Scaffold(body: PaymentMethodPicker()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select Payment Method'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == darkColors.surface,
      ),
      findsWidgets,
    );
    final search = tester.widget<TextField>(
      find.byKey(const ValueKey('payment-search-field')),
    );
    expect(search.decoration?.fillColor, darkColors.surfaceContainerHighest);
  });

  testWidgets('disabled AI analysis action uses a dark raised surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(
            (ref) async => Session(
              token: 'test-token',
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
              username: 'dark-mode-test',
              isGuest: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: darkTheme,
          home: const Scaffold(body: ScanPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final darkButton = find.ancestor(
      of: find.text('Analyze with AI'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.color == darkColors.surfaceContainerHighest,
      ),
    );
    expect(darkButton, findsOneWidget);
  });
}
