import 'package:broke_ai_app/models/expense_summary.dart';
import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/models/transaction.dart';
import 'package:broke_ai_app/pages/home_page.dart';
import 'package:broke_ai_app/providers/app_providers.dart';
import 'package:broke_ai_app/services/expense_export_service.dart';
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
    final exporter = _FakeExpenseExportService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) async => session),
          expenseExportServiceProvider.overrideWithValue(exporter),
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
    expect(find.text('Export to Excel (.xlsx)'), findsOneWidget);
    expect(find.text('View full report'), findsNothing);
    expect(find.byType(Divider), findsNothing);

    await tester.tap(find.text('Export to Excel (.xlsx)'));
    await tester.pumpAndSettle();
    expect(exporter.exportCount, 1);
    expect(exporter.transactions, transactions);
  });
}

class _FakeExpenseExportService extends ExpenseExportService {
  int exportCount = 0;
  List<Transaction>? transactions;

  @override
  Future<Never> exportMonthly({
    required List<Transaction> transactions,
    required DateTime month,
  }) async {
    exportCount++;
    this.transactions = transactions;
    throw StateError('Share sheet suppressed in widget test.');
  }
}
