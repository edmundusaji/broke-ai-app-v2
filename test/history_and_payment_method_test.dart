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
  date: '2026-08-04',
  amount: 75000,
  category: 'Donation',
  paymentMethod: 'OVO',
  description: 'KitaBisa Donation',
  inputType: 'MANUAL',
);

const recentTransaction = Transaction(
  id: 13,
  date: '2026-08-05',
  amount: 50000,
  category: 'Health',
  paymentMethod: 'GoPay',
  description: 'Cold Medicine',
  inputType: 'MANUAL',
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('payment method visuals map known brands', () {
    expect(paymentMethodLogoAsset('OVO'), 'assets/logos/e-wallet/OVO.png');
    expect(paymentMethodLogoAsset('Unknown payment'), isNull);
  });

  test('transaction maps AI and manual response fields without synthesis', () {
    final parsed = Transaction.fromJson(const {
      'id': 14,
      'date': '2026-08-05T13:14:15',
      'amount': 25000,
      'category': 'Food',
      'paymentMethod': 'QRIS',
      'description': 'Coffee Purchase',
      'inputType': 'RECEIPT',
      'validationStatus': 'PENDING',
    });

    expect(parsed.paymentMethod, 'QRIS');
    expect(parsed.description, 'Coffee Purchase');
    expect(parsed.inputType, 'RECEIPT');
    expect(parsed.validationStatus, 'PENDING');
    expect(parsed.toJson(), containsPair('amount', 25000.0));
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
              recent: const [recentTransaction],
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Health'), findsOneWidget);
    expect(find.textContaining('Cold Medicine'), findsOneWidget);
    expect(find.text('Donation'), findsNothing);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction history'), findsOneWidget);
    expect(find.text('Donation'), findsOneWidget);
    expect(find.textContaining('KitaBisa Donation'), findsOneWidget);
    expect(find.text('Health'), findsNothing);

    await tester.tap(find.text('Donation'));
    await tester.pumpAndSettle();
    expect(find.text('Edit transaction'), findsOneWidget);
    expect(find.text('Delete transaction'), findsOneWidget);
  });
}
