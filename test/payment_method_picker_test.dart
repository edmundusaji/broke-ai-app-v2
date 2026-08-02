import 'package:broke_ai_app/payment_method_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payment catalog contains all structured groups and options', () {
    expect(paymentMethodGroups, hasLength(9));
    expect(
      paymentMethodGroups.expand((group) => group.options),
      containsAll(<String>[
        'Bank BCA',
        'Credit/Debit Card (Visa, Mastercard, JCB, Amex)',
        'QRIS (Scan all e-wallets / mobile banking)',
        'GoPay',
        'Akulaku Paylater',
        'Jenius Pay',
        'OneKlik',
        'Indomaret',
        'Cash / Pay on Delivery',
      ]),
    );
  });

  testWidgets('search filters across groups and returns the selected method', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showPaymentMethodPicker(context);
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search banks, wallets, cards...'),
      'gopay',
    );
    await tester.pumpAndSettle();

    expect(find.text('E-Wallet (Uang Elektronik)'), findsOneWidget);
    expect(find.text('GoPay'), findsOneWidget);
    expect(find.text('Bank BCA'), findsNothing);

    await tester.tap(find.text('GoPay'));
    await tester.pumpAndSettle();
    expect(selected, 'GoPay');
  });
}
