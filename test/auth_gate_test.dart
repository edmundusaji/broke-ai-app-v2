import 'package:broke_ai_app/app.dart';
import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/providers/app_providers.dart';
import 'package:broke_ai_app/services/app_lock_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('restored account session is gated by persisted app lock', (
    tester,
  ) async {
    final session = Session(
      token: 'account-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      username: 'edmund',
      isGuest: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) async => session),
          appLockSettingsProvider.overrideWith(
            (ref) async => const AppLockSettings(enabled: true),
          ),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();

    expect(find.text('Unlock Broke.AI'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('startup shows the branded boot page before routing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) async => null)],
        child: const MaterialApp(home: AuthGate()),
      ),
    );

    expect(find.text('BROKE.AI'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('How would you like to start?'),
      findsOneWidget,
    );
  });

  testWidgets('signed-out startup shows guest and account entry options', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) async => null)],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('How would you like to start?'),
      findsOneWidget,
    );
    expect(find.text('Try Now'), findsOneWidget);
    expect(find.text('Sign In / Register'), findsOneWidget);
  });

  testWidgets('auth screen can return to the account-choice landing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) async => null)],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();

    final accountButton = find.text('Sign In / Register');
    await tester.ensureVisible(accountButton);
    await tester.tap(accountButton);
    await tester.pumpAndSettle();
    expect(find.text('Welcome\nback.'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to start options'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('How would you like to start?'),
      findsOneWidget,
    );
  });
}
