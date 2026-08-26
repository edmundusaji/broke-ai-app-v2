import 'package:broke_ai_app/core/app_theme.dart';
import 'package:broke_ai_app/models/account_settings.dart';
import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/pages/currency_language_page.dart';
import 'package:broke_ai_app/pages/data_privacy_page.dart';
import 'package:broke_ai_app/pages/help_faq_page.dart';
import 'package:broke_ai_app/pages/notifications_settings_page.dart';
import 'package:broke_ai_app/pages/profile_page.dart';
import 'package:broke_ai_app/providers/app_providers.dart';
import 'package:broke_ai_app/services/api_client.dart';
import 'package:broke_ai_app/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SessionStore sessionStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sessionStore = SessionStore();
    await sessionStore.save(
      Session(
        token: 'offline-token',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        username: 'offline-user',
        isGuest: false,
        fullName: 'Offline User',
        email: 'offline@example.com',
      ),
    );
  });

  ProviderContainer container() => ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(sessionStore),
      sessionProvider.overrideWith((ref) => sessionStore.read()),
      apiProvider.overrideWithValue(_UnavailableSettingsApi()),
    ],
  );

  Widget app(ProviderContainer container, Widget child) =>
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: buildAppTheme(),
            darkTheme: buildDarkAppTheme(),
            themeMode: ref.watch(themeModeProvider),
            home: child,
          ),
        ),
      );

  testWidgets(
    'dark mode remains selected when preference sync is unavailable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final scope = container();
      addTearDown(scope.dispose);
      await tester.pumpWidget(app(scope, const Scaffold(body: ProfilePage())));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Appearance'));
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(find.text('Dark mode is active'), findsOneWidget);
      expect(scope.read(themeModeProvider), ThemeMode.dark);
      final cached = await scope
          .read(settingsRepositoryProvider)
          .accountPreferences();
      expect(cached.themeMode, 'dark');
    },
  );

  testWidgets('settings and FAQ stay complete when settings APIs fail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final scope = container();
    addTearDown(scope.dispose);

    await tester.pumpWidget(app(scope, const DataPrivacyPage()));
    await tester.pumpAndSettle();
    expect(find.text('Export my data'), findsOneWidget);
    expect(find.text('Personalized insights'), findsOneWidget);
    expect(find.text('Saved on this device'), findsOneWidget);

    await tester.pumpWidget(app(scope, const HelpFaqPage()));
    await tester.pumpAndSettle();
    expect(find.text('How does receipt scanning work?'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);

    await tester.pumpWidget(app(scope, const NotificationsSettingsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Spending reminders'), findsOneWidget);
    expect(find.text('Security alerts'), findsOneWidget);

    await tester.pumpWidget(app(scope, const CurrencyLanguagePage()));
    await tester.pumpAndSettle();
    expect(find.text('Primary currency'), findsOneWidget);
    expect(find.text('App language'), findsOneWidget);
  });
}

class _UnavailableSettingsApi extends ApiClient {
  _UnavailableSettingsApi() : super(SessionStore());

  StateError get unavailable => StateError('Settings service unavailable');

  @override
  Future<AccountPreferences> getPreferences() => Future.error(unavailable);

  @override
  Future<AccountPreferences> updatePreferences({
    required int revision,
    String? currencyCode,
    String? languageCode,
    String? regionCode,
    String? timeZone,
    String? themeMode,
  }) => Future.error(unavailable);

  @override
  Future<NotificationPreferences> getNotificationPreferences() =>
      Future.error(unavailable);

  @override
  Future<NotificationPreferences> updateNotificationPreferences({
    required int revision,
    bool? spendingReminderEnabled,
    String? reminderTime,
    bool? weeklySummaryEnabled,
    bool? monthlyReportEnabled,
    bool? securityAlertsEnabled,
    bool? productUpdatesEnabled,
  }) => Future.error(unavailable);

  @override
  Future<PrivacyPreferences> getPrivacyPreferences() =>
      Future.error(unavailable);

  @override
  Future<PrivacyPreferences> updatePrivacyPreferences({
    required int revision,
    required String policyVersion,
    bool? personalizedInsights,
    bool? anonymousAnalytics,
  }) => Future.error(unavailable);

  @override
  Future<SyncStatus> syncStatus() => Future.error(unavailable);

  @override
  Future<List<FaqArticle>> faqs({String locale = 'en'}) =>
      Future.error(unavailable);
}
