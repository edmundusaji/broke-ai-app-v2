import 'package:broke_ai_app/models/expense_summary.dart';
import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/models/transaction.dart';
import 'package:broke_ai_app/pages/home_page.dart';
import 'package:broke_ai_app/providers/app_providers.dart';
import 'package:broke_ai_app/utils/transaction_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const transaction = Transaction(
  id: 12,
  tanggal: '2026-08-04',
  jumlah: 75000,
  kategori: 'Donation',
  merchant: 'OVO',
  tipeInput: 'MANUAL',
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('merchant visuals map known brands and create a useful description', () {
    expect(merchantLogoAsset('OVO'), 'assets/logos/e-wallet/OVO.png');
    expect(merchantLogoAsset('Unknown payment'), isNull);
    expect(transactionDescription(transaction), 'Donation via OVO');
  });

  testWidgets('History CTA opens full history with edit and delete actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = Session(
      token: 'token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      username: 'edmund',
      isGuest: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) async => session),
          dashboardProvider.overrideWith(
            (ref) async => (
              summary: const ExpenseSummary(75000, [
                CategorySummary('Donation', 75000),
              ]),
              history: const [transaction],
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction history'), findsOneWidget);

    await tester.tap(find.text('Donation'));
    await tester.pumpAndSettle();
    expect(find.text('Edit transaction'), findsOneWidget);
    expect(find.text('Delete transaction'), findsOneWidget);
  });
}
