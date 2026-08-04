import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/pages/scan_page.dart';
import 'package:broke_ai_app/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Session _guestSession(int remainingTrials) => Session(
  token: 'guest-token',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  username: 'guest_123',
  isGuest: true,
  remainingAiTrials: remainingTrials,
  name: 'Guest User',
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('guest scan screen shows the shared remaining trial count', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) async => _guestSession(2)),
          remainingAiTrialsProvider.overrideWith((ref) => 2),
        ],
        child: const MaterialApp(home: Scaffold(body: ScanPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 Free Scans Left'), findsOneWidget);
  });

  testWidgets('exhausted guest is blocked before an AI request', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) async => _guestSession(0)),
          remainingAiTrialsProvider.overrideWith((ref) => 0),
        ],
        child: const MaterialApp(home: Scaffold(body: ScanPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Free Scans Left'), findsOneWidget);
    final input = find.byType(TextField);
    expect(input, findsOneWidget);
    await tester.enterText(input, 'Paid Rp 25.000 with GoPay');

    final processButton = find.text('Process with AI');
    await tester.ensureVisible(processButton);
    await tester.tap(processButton);
    await tester.pumpAndSettle();

    expect(find.text('Unlock Unlimited AI Scans!'), findsOneWidget);
    expect(find.text('Sign In / Register'), findsOneWidget);
    expect(find.text('Use Manual Input'), findsOneWidget);

    await tester.tap(find.text('Use Manual Input'));
    await tester.pumpAndSettle();
    expect(find.text('Manual transaction'), findsOneWidget);
  });
}
