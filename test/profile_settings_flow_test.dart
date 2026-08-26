import 'package:broke_ai_app/core/app_theme.dart';
import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/models/account_settings.dart';
import 'package:broke_ai_app/pages/currency_language_page.dart';
import 'package:broke_ai_app/pages/data_privacy_page.dart';
import 'package:broke_ai_app/pages/help_faq_page.dart';
import 'package:broke_ai_app/pages/manage_profile_page.dart';
import 'package:broke_ai_app/pages/notifications_settings_page.dart';
import 'package:broke_ai_app/pages/profile_page.dart';
import 'package:broke_ai_app/pages/security_page.dart';
import 'package:broke_ai_app/providers/app_providers.dart';
import 'package:broke_ai_app/services/api_client.dart';
import 'package:broke_ai_app/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Session accountSession() => Session(
    token: 'token',
    expiresAt: DateTime.now().add(const Duration(days: 1)),
    username: 'ed',
    isGuest: false,
    fullName: 'Edmund Aji',
    email: 'edmund@example.com',
  );

  Widget app(Widget child) => ProviderScope(
    overrides: [
      sessionProvider.overrideWith((ref) async => accountSession()),
      apiProvider.overrideWithValue(_SettingsApi()),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        theme: buildAppTheme(),
        darkTheme: buildDarkAppTheme(),
        themeMode: ref.watch(themeModeProvider),
        home: child,
      ),
    ),
  );

  testWidgets('profile opens editable profile and validates fields', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const Scaffold(body: ProfilePage())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ManageProfilePage), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email address'), findsOneWidget);
  });

  testWidgets('security provides password and app lock controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const SecurityPage()));
    await tester.pumpAndSettle();

    expect(find.text('Update password'), findsOneWidget);
    expect(find.text('Require app lock'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('Create app lock PIN'), findsOneWidget);
  });

  testWidgets('currency choice updates the preference', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith((ref) async => accountSession()),
        apiProvider.overrideWithValue(_SettingsApi()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CurrencyLanguagePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Primary currency'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('US Dollar'));
    await tester.pumpAndSettle();
    expect(container.read(localePreferencesProvider).currencyCode, 'USD');
  });

  testWidgets('appearance sheet switches the global app theme', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const Scaffold(body: ProfilePage())));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Appearance'));
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Light mode is active'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(find.text('Dark mode is active'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(ProfilePage))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('data and support pages expose complete frontend controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(const DataPrivacyPage()));
    await tester.pumpAndSettle();
    expect(find.text('Export my data'), findsOneWidget);
    expect(find.text('Personalized insights'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);

    await tester.pumpWidget(app(const HelpFaqPage()));
    await tester.pumpAndSettle();
    expect(find.text('How does receipt scanning work?'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);

    await tester.pumpWidget(app(const NotificationsSettingsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Spending reminders'), findsOneWidget);
    expect(find.text('Security alerts'), findsOneWidget);
  });
}

class _SettingsApi extends ApiClient {
  _SettingsApi() : super(SessionStore());

  var preferences = const AccountPreferences(
    currencyCode: 'IDR',
    languageCode: 'en',
    regionCode: 'ID',
    timeZone: 'Asia/Jakarta',
    themeMode: 'light',
    revision: 1,
  );

  @override
  Future<AccountProfile> getProfile() async => const AccountProfile(
    id: 1,
    fullName: 'Edmund Aji',
    username: 'ed',
    email: 'edmund@example.com',
    status: 'active',
    revision: 1,
  );

  @override
  Future<List<AccountSession>> sessions() async => const [];

  @override
  Future<AccountPreferences> getPreferences() async => preferences;

  @override
  Future<AccountPreferences> updatePreferences({
    required int revision,
    String? currencyCode,
    String? languageCode,
    String? regionCode,
    String? timeZone,
    String? themeMode,
  }) async {
    preferences = AccountPreferences(
      currencyCode: currencyCode ?? preferences.currencyCode,
      languageCode: languageCode ?? preferences.languageCode,
      regionCode: regionCode ?? preferences.regionCode,
      timeZone: timeZone ?? preferences.timeZone,
      themeMode: themeMode ?? preferences.themeMode,
      revision: preferences.revision + 1,
    );
    return preferences;
  }

  @override
  Future<NotificationPreferences> getNotificationPreferences() async =>
      const NotificationPreferences(
        spendingReminderEnabled: true,
        reminderTime: '20:00:00',
        weeklySummaryEnabled: true,
        monthlyReportEnabled: true,
        securityAlertsEnabled: true,
        productUpdatesEnabled: false,
        revision: 1,
      );

  @override
  Future<PrivacyPreferences> getPrivacyPreferences() async =>
      const PrivacyPreferences(
        personalizedInsights: true,
        anonymousAnalytics: true,
        policyVersion: '2026-01',
        revision: 1,
      );

  @override
  Future<SyncStatus> syncStatus() async =>
      const SyncStatus(status: 'synced', serverRevision: 1);

  @override
  Future<List<FaqArticle>> faqs({String locale = 'en'}) async => const [
    FaqArticle(
      id: 'faq-1',
      locale: 'en',
      category: 'scanning',
      title: 'How does receipt scanning work?',
      body: 'Take a clear photo and review the detected fields.',
    ),
  ];
}
