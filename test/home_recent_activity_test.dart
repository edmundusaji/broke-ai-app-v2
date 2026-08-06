import 'package:broke_ai_app/models/expense_summary.dart';
import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/models/transaction.dart';
import 'package:broke_ai_app/pages/home_page.dart';
import 'package:broke_ai_app/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en_US'));

  testWidgets('newest activities render without separator lines', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 940));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final session = Session(
      token: 'test-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      username: 'guest_test',
      isGuest: true,
      fullName: 'Guest User',
    );
    const transactions = [
      Transaction(
        id: 1,
        date: '2026-08-07',
        amount: 3000,
        category: 'Food',
        paymentMethod: 'OVO',
        description: 'KFC',
      ),
      Transaction(
        id: 2,
        date: '2026-08-07',
        amount: 2500,
        category: 'Transport',
        paymentMethod: 'GoPay',
        description: 'Ride home',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) async => session),
          dashboardProvider.overrideWith(
            (ref) async => (
              summary: const ExpenseSummary(5500, [
                CategorySummary('Food', 3000),
                CategorySummary('Transport', 2500),
              ]),
              history: transactions,
              recent: transactions,
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Newest activities'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
  });
}
