import 'dart:convert';
import 'dart:typed_data';

import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/models/account_settings.dart';
import 'package:broke_ai_app/models/transaction.dart';
import 'package:broke_ai_app/pages/profile_page.dart';
import 'package:broke_ai_app/pages/register_page.dart';
import 'package:broke_ai_app/pages/help_faq_page.dart';
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
  fullName: isGuest ? 'Guest User' : 'Edmund',
  email: isGuest ? null : 'edmund@example.com',
);

const _transaction = Transaction(
  id: 21,
  date: '2026-08-05T14:20:31',
  amount: 45000,
  category: 'Food',
  paymentMethod: 'GoPay',
  description: 'Lunch at the office',
  inputType: 'MANUAL',
  validationStatus: 'CONFIRMED',
);

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({
    this.responseData = const {
      'id': 22,
      'date': '2026-08-05T14:20:31',
      'amount': 45000,
      'category': 'Food',
      'paymentMethod': 'GoPay',
      'description': 'Lunch at the office',
      'inputType': 'MANUAL',
      'validationStatus': 'CONFIRMED',
    },
  });

  final Object responseData;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(responseData),
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

  test('registration sends fullName and login reads fullName', () async {
    SharedPreferences.setMockInitialValues({
      'base_url': 'https://example.test/api/v1/',
    });
    final store = SessionStore();
    final registerAdapter = _RecordingAdapter(responseData: const {});
    final registerApi = ApiClient(
      store,
      dio: Dio()..httpClientAdapter = registerAdapter,
    );

    await registerApi.register(
      fullName: 'Edmund Aji',
      username: 'edmund',
      email: 'edmund@example.com',
      password: 'secret123',
    );
    expect(registerAdapter.request?.data, {
      'fullName': 'Edmund Aji',
      'username': 'edmund',
      'email': 'edmund@example.com',
      'password': 'secret123',
    });

    final loginAdapter = _RecordingAdapter(
      responseData: const {
        'token': 'account-token',
        'expiresIn': 3600,
        'username': 'edmund',
        'isGuest': false,
        'user': {'fullName': 'Edmund Aji', 'email': 'edmund@example.com'},
      },
    );
    final loginApi = ApiClient(
      store,
      dio: Dio()..httpClientAdapter = loginAdapter,
    );
    final session = await loginApi.login('edmund', 'secret123');

    expect(session.fullName, 'Edmund Aji');
    expect(session.displayName, 'Edmund Aji');
  });

  testWidgets('guest profile exposes account protection and guest controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
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

    expect(find.text('Create account'), findsWidgets);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
    expect(find.text('AI scans remaining'), findsOneWidget);
    expect(find.text('Currency & language'), findsOneWidget);
    expect(find.text('Delete guest data'), findsOneWidget);
    expect(find.text('Manage profile'), findsNothing);
    expect(find.text('Log out'), findsNothing);

    await tester.ensureVisible(find.text('App lock'));
    await tester.tap(find.text('App lock'));
    await tester.pumpAndSettle();
    expect(find.text('Device-only protection'), findsOneWidget);
    expect(find.text('Change password'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account').first);
    expect(container.read(showAuthProvider), isTrue);
    expect(container.read(authStartInLoginProvider), isFalse);

    container.read(showAuthProvider.notifier).state = false;
    await tester.tap(find.text('Already have an account? Sign in'));
    expect(container.read(showAuthProvider), isTrue);
    expect(container.read(authStartInLoginProvider), isTrue);
  });

  testWidgets('guest bug report keeps the form local before sign-in', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _session(isGuest: true)),
        ],
        child: const MaterialApp(home: HelpFaqPage(openBugReport: true)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Describe what you expected and what happened.'),
      findsOneWidget,
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'Receipt scan failed');
    await tester.enterText(
      fields.at(2),
      'The scanner stopped after selection.',
    );
    await tester.tap(find.text('Submit bug report'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Sign in to submit'), findsOneWidget);
    expect(find.text('Share draft'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('account profile retains the logout action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _session(isGuest: false)),
          syncStatusProvider.overrideWith(
            (ref) async =>
                const SyncStatus(status: 'synced', serverRevision: 1),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfilePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Login / Register'), findsNothing);
    expect(find.text('edmund@example.com'), findsOneWidget);
    expect(find.text('Your data is protected'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Currency & language'), findsOneWidget);
    expect(find.text('Data & privacy'), findsOneWidget);
    expect(find.text('Server settings'), findsNothing);

    await tester.tap(find.text('View backup'));
    await tester.pumpAndSettle();
    expect(find.text('Backup & sync'), findsOneWidget);
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

    expect(find.text('Save your\nguest history'), findsOneWidget);
    final signInToggle = find.text('Already have an account? Sign in');
    await tester.ensureVisible(signInToggle);
    await tester.tap(signInToggle);
    await tester.pumpAndSettle();
    expect(find.text('Welcome\nback.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'existing-user');
    await tester.enterText(find.byType(TextField).at(1), 'password123!');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('What happens to guest history?'), findsOneWidget);
    expect(find.text('Sign in & merge'), findsOneWidget);
  });

  testWidgets('registration collects account details across three steps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => _session(isGuest: true)),
        ],
        child: const MaterialApp(home: RegisterPage()),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('register-full-name')),
      'Edmund Aji',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-email')),
      'edmund@example.com',
    );
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Secure your\naccount'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('register-username')),
      'edmund',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-password')),
      'secret123!',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password')),
      'secret123!',
    );
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('You’re all set!'), findsOneWidget);
    expect(find.text('Edmund Aji'), findsOneWidget);
    expect(find.text('edmund@example.com'), findsOneWidget);
    expect(find.text('edmund'), findsOneWidget);
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
