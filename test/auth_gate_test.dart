import 'package:broke_ai_app/app.dart';
import 'package:broke_ai_app/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    expect(find.text('How would you like to start?'), findsOneWidget);
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
    expect(find.text('Welcome back.'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to start options'));
    await tester.pumpAndSettle();
    expect(find.text('How would you like to start?'), findsOneWidget);
  });
}
