import 'dart:convert';
import 'dart:typed_data';

import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/models/transaction.dart';
import 'package:broke_ai_app/pages/profile_page.dart';
import 'package:broke_ai_app/pages/register_page.dart';
import 'package:broke_ai_app/providers/app_providers.dart';
import 'package:broke_ai_app/services/api_client.dart';
import 'package:broke_ai_app/services/session_store.dart';
import 'package:broke_ai_app/widgets/manual_transaction_sheet.dart';
import 'package:broke_ai_app/widgets/payment_method_logo.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

Session _session({required bool isGuest}) => Session(
  token: isGuest ? 'guest-token' : 'account-token',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  username: isGuest ? 'guest_123' : 'edmund',
  isGuest: isGuest,
  name: isGuest ? 'Guest User' : 'Edmund',
);

const _transaction = Transaction(
  id: 21,
  tanggal: '2026-08-05T14:20:31',
  jumlah: 45000,
  kategori: 'Food',
  paymentMethod: 'GoPay',
  description: 'Lunch at the office',
  tipeInput: 'MANUAL',
);

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'id': 22,
        'tanggal': '2026-08-05T14:20:31',
        'jumlah': 45000,
        'kategori': 'Food',
        'paymentMethod': 'GoPay',
        'description': 'Lunch at the office',
        'tipeInput': 'MANUAL',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('manual API payload uses paymentMethod and description', () async {
    SharedPreferences.setMockInitialValues({
      'base_url': 'https://example.test/api/v1/',
    });
    final store = SessionStore();
    await store.save(_session(isGuest: true));
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ApiClient(store, dio: dio);

    final result = await api.createManualTransaction(
      date: DateTime(2026, 8, 5),
      amount: 45000,
      category: 'Food',
      paymentMethod: 'GoPay',
      description: 'Lunch at the office',
    );

    expect(adapter.request?.path, 'https://example.test/api/v1/expense/manual');
    expect(adapter.request?.data, {
      'date': '2026-08-05',
      'amount': 45000.0,
      'category': 'Food',
      'paymentMethod': 'GoPay',
      'description': 'Lunch at the office',
    });
    expect(result.paymentMethod, 'GoPay');
    expect(result.description, 'Lunch at the office');
  });

  testWidgets('guest profile replaces logout with Login / Register', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) => _session(isGuest: true)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login / Register'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);

    await tester.tap(find.text('Login / Register'));
    expect(container.read(showAuthProvider), isTrue);
  });

  testWidgets('account profile retains the logout action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _session(isGuest: false)),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Login / Register'), findsNothing);
  });

  testWidgets('guest authentication screen offers registration and sign in', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _session(isGuest: true)),
        ],
        child: const MaterialApp(home: RegisterPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Save your guest history.'), findsOneWidget);
    final signInToggle = find.text('Already have an account? Sign in');
    await tester.ensureVisible(signInToggle);
    await tester.tap(signInToggle);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);
  });

  testWidgets('manual edit form includes the backend description', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ManualTransactionSheet(transaction: _transaction),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == 'Lunch at the office',
      ),
      findsOneWidget,
    );
    expect(find.text('GoPay'), findsOneWidget);
  });

  testWidgets('unknown payment methods use the default wallet icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PaymentMethodLogo(paymentMethod: 'Unknown payment'),
        ),
      ),
    );

    expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
  });
}
