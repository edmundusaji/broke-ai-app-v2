import 'package:broke_ai_app/pages/app_lock_page.dart';
import 'package:broke_ai_app/pages/app_lock_recovery_page.dart';
import 'package:broke_ai_app/pages/register_page.dart';
import 'package:broke_ai_app/providers/app_providers.dart';
import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/services/api_client.dart';
import 'package:broke_ai_app/services/app_lock_service.dart';
import 'package:broke_ai_app/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('app lock survives a service restart and verifies its PIN', () async {
    final firstProcess = AppLockService();
    await firstProcess.enable('2468');
    await firstProcess.setLockAfter('After 1 minute');

    final restartedProcess = AppLockService();
    final settings = await restartedProcess.read();

    expect(settings.enabled, isTrue);
    expect(settings.lockAfter, 'After 1 minute');
    expect(await restartedProcess.verifyPin('2468'), isTrue);
    expect(await restartedProcess.verifyPin('1357'), isFalse);
  });

  test('disabling app lock removes the persisted PIN', () async {
    final service = AppLockService();
    await service.enable('2468');
    await service.disable();

    expect((await AppLockService().read()).enabled, isFalse);
    expect(await AppLockService().verifyPin('2468'), isFalse);
  });

  testWidgets('locked content only opens after the correct PIN', (
    tester,
  ) async {
    final service = _FakeAppLockService('2468');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appLockServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => ref.watch(appUnlockedProvider)
                ? const Scaffold(body: Text('Protected content'))
                : const AppLockPage(),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '1111');
    await tester.tap(find.text('Unlock'));
    await tester.pump();
    expect(find.text('That PIN is incorrect. Try again.'), findsOneWidget);
    expect(find.text('Protected content'), findsNothing);

    await tester.enterText(find.byType(TextField), '2468');
    await tester.tap(find.text('Unlock'));
    await tester.pump();
    expect(find.text('Protected content'), findsOneWidget);
  });

  testWidgets('Forgot PIN starts account reauthentication', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppLockPage()),
      ),
    );

    await tester.tap(find.text('Forgot PIN?'));
    await tester.pump();

    expect(container.read(showAuthProvider), isTrue);
    expect(
      container.read(appLockRecoveryProvider),
      AppLockRecoveryStep.reauthenticate,
    );
    expect(container.read(appUnlockedProvider), isFalse);
  });

  testWidgets('successful recovery login advances to PIN choices', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = SessionStore();
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        sessionProvider.overrideWith((ref) async => null),
        apiProvider.overrideWithValue(_RecoveryApi()),
      ],
    );
    addTearDown(container.dispose);
    container.read(appLockRecoveryProvider.notifier).state =
        AppLockRecoveryStep.reauthenticate;
    container.read(showAuthProvider.notifier).state = true;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RegisterPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New here? Register'), findsNothing);
    await tester.enterText(find.byType(TextField).at(0), 'edmund');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(
      container.read(appLockRecoveryProvider),
      AppLockRecoveryStep.chooseAction,
    );
    expect(container.read(appUnlockedProvider), isFalse);
  });

  testWidgets('Later deactivates app lock before continuing', (tester) async {
    final service = _FakeAppLockService('2468');
    final container = ProviderContainer(
      overrides: [appLockServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.read(appLockRecoveryProvider.notifier).state =
        AppLockRecoveryStep.chooseAction;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppLockRecoveryChoicePage()),
      ),
    );

    await tester.tap(find.text('Later'));
    await tester.pump();

    expect(service.disabled, isTrue);
    expect(container.read(appUnlockedProvider), isTrue);
    expect(container.read(appLockRecoveryProvider), AppLockRecoveryStep.none);
  });

  testWidgets('Change PIN saves the replacement before continuing', (
    tester,
  ) async {
    final service = _FakeAppLockService('2468');
    final container = ProviderContainer(
      overrides: [appLockServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.read(appLockRecoveryProvider.notifier).state =
        AppLockRecoveryStep.changePin;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppLockChangePinPage()),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '1357');
    await tester.enterText(find.byType(TextField).at(1), '1357');
    await tester.tap(find.text('Save new PIN'));
    await tester.pump();

    expect(service.pin, '1357');
    expect(container.read(appUnlockedProvider), isTrue);
    expect(container.read(appLockRecoveryProvider), AppLockRecoveryStep.none);
  });
}

class _FakeAppLockService extends AppLockService {
  _FakeAppLockService(this.pin);

  String pin;
  bool disabled = false;

  @override
  Future<bool> verifyPin(String candidate) async => candidate == pin;

  @override
  Future<void> replacePin(String replacement) async => pin = replacement;

  @override
  Future<void> disable() async => disabled = true;
}

class _RecoveryApi extends ApiClient {
  _RecoveryApi() : super(SessionStore());

  @override
  Future<Session> login(String username, String password) async => Session(
    token: 'replacement-session',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    username: username,
    isGuest: false,
  );
}
