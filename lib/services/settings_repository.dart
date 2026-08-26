import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_settings.dart';
import 'api_client.dart';

class SettingsRepository {
  SettingsRepository(this._api, {String? accountScope, this._localOnly = false})
    : _accountScope = accountScope?.trim().toLowerCase() ?? 'device';

  final ApiClient _api;
  final String _accountScope;
  final bool _localOnly;

  static const defaultAccountPreferences = AccountPreferences(
    currencyCode: 'IDR',
    languageCode: 'en',
    regionCode: 'ID',
    timeZone: 'Asia/Jakarta',
    themeMode: 'light',
    revision: 0,
  );

  static const defaultNotificationPreferences = NotificationPreferences(
    spendingReminderEnabled: true,
    reminderTime: '20:00:00',
    weeklySummaryEnabled: true,
    monthlyReportEnabled: true,
    securityAlertsEnabled: true,
    productUpdatesEnabled: false,
    revision: 0,
  );

  static const defaultPrivacyPreferences = PrivacyPreferences(
    personalizedInsights: true,
    anonymousAnalytics: true,
    policyVersion: '2026-01',
    revision: 0,
  );

  static const builtInFaqs = <FaqArticle>[
    FaqArticle(
      id: 'local-scan',
      locale: 'en',
      category: 'scanning',
      title: 'How does receipt scanning work?',
      body:
          'Take or upload a clear receipt photo. Broke.AI extracts the merchant, amount, category, and payment method for you to review.',
    ),
    FaqArticle(
      id: 'local-manual',
      locale: 'en',
      category: 'transactions',
      title: 'Can I add or edit a transaction manually?',
      body:
          'Yes. Use the plus button to add an expense manually. Open History to edit or delete an existing transaction.',
    ),
    FaqArticle(
      id: 'local-privacy',
      locale: 'en',
      category: 'privacy',
      title: 'How is my financial data protected?',
      body:
          'Your account session is stored securely on your device. Privacy choices can be changed from Data & privacy at any time.',
    ),
    FaqArticle(
      id: 'local-notifications',
      locale: 'en',
      category: 'notifications',
      title: 'How do I change reminders and notifications?',
      body:
          'Open Profile, choose Notifications, then enable only the reminders and account updates you want to receive.',
    ),
    FaqArticle(
      id: 'local-theme',
      locale: 'en',
      category: 'appearance',
      title: 'How do I switch between light and dark mode?',
      body:
          'Open Profile, choose Appearance, and select Light or Dark. The choice is saved on this device immediately.',
    ),
  ];

  Future<AccountPreferences> accountPreferences() async {
    final local = await _read(
      'account',
      AccountPreferences.fromJson,
      defaultAccountPreferences,
    );
    if (_localOnly) return local;
    if (await _isPending('account')) {
      try {
        final synced = await _api.updatePreferences(
          revision: local.revision,
          currencyCode: local.currencyCode,
          languageCode: local.languageCode,
          regionCode: local.regionCode,
          timeZone: local.timeZone,
          themeMode: local.themeMode,
        );
        await _write('account', synced.toJson());
        await _setPending('account', false);
        return synced;
      } catch (error, stackTrace) {
        _logFallback('retry account preferences', error, stackTrace);
        return local;
      }
    }
    try {
      final value = await _api.getPreferences();
      await _write('account', value.toJson());
      return value;
    } catch (error, stackTrace) {
      _logFallback('load account preferences', error, stackTrace);
      return local;
    }
  }

  Future<AccountPreferences> updateAccountPreferences({
    required AccountPreferences current,
    String? currencyCode,
    String? languageCode,
    String? regionCode,
    String? timeZone,
    String? themeMode,
  }) async {
    final local = current.copyWith(
      currencyCode: currencyCode,
      languageCode: languageCode,
      regionCode: regionCode,
      timeZone: timeZone,
      themeMode: themeMode,
    );
    await _write('account', local.toJson());
    if (_localOnly) {
      await _setPending('account', false);
      return local;
    }
    await _setPending('account', true);
    try {
      final synced = await _api.updatePreferences(
        revision: current.revision,
        currencyCode: currencyCode,
        languageCode: languageCode,
        regionCode: regionCode,
        timeZone: timeZone,
        themeMode: themeMode,
      );
      await _write('account', synced.toJson());
      await _setPending('account', false);
      return synced;
    } catch (error, stackTrace) {
      _logFallback('sync account preferences', error, stackTrace);
      return local;
    }
  }

  Future<NotificationPreferences> notificationPreferences() async {
    final local = await _read(
      'notifications',
      NotificationPreferences.fromJson,
      defaultNotificationPreferences,
    );
    if (_localOnly) return local;
    if (await _isPending('notifications')) {
      try {
        final synced = await _api.updateNotificationPreferences(
          revision: local.revision,
          spendingReminderEnabled: local.spendingReminderEnabled,
          reminderTime: local.reminderTime,
          weeklySummaryEnabled: local.weeklySummaryEnabled,
          monthlyReportEnabled: local.monthlyReportEnabled,
          securityAlertsEnabled: local.securityAlertsEnabled,
          productUpdatesEnabled: local.productUpdatesEnabled,
        );
        await _write('notifications', synced.toJson());
        await _setPending('notifications', false);
        return synced;
      } catch (error, stackTrace) {
        _logFallback('retry notification preferences', error, stackTrace);
        return local;
      }
    }
    try {
      final value = await _api.getNotificationPreferences();
      await _write('notifications', value.toJson());
      return value;
    } catch (error, stackTrace) {
      _logFallback('load notification preferences', error, stackTrace);
      return local;
    }
  }

  Future<NotificationPreferences> updateNotificationPreferences({
    required NotificationPreferences current,
    bool? spendingReminderEnabled,
    String? reminderTime,
    bool? weeklySummaryEnabled,
    bool? monthlyReportEnabled,
    bool? securityAlertsEnabled,
    bool? productUpdatesEnabled,
  }) async {
    final local = current.copyWith(
      spendingReminderEnabled: spendingReminderEnabled,
      reminderTime: reminderTime,
      weeklySummaryEnabled: weeklySummaryEnabled,
      monthlyReportEnabled: monthlyReportEnabled,
      securityAlertsEnabled: securityAlertsEnabled,
      productUpdatesEnabled: productUpdatesEnabled,
    );
    await _write('notifications', local.toJson());
    if (_localOnly) {
      await _setPending('notifications', false);
      return local;
    }
    await _setPending('notifications', true);
    try {
      final synced = await _api.updateNotificationPreferences(
        revision: current.revision,
        spendingReminderEnabled: spendingReminderEnabled,
        reminderTime: reminderTime,
        weeklySummaryEnabled: weeklySummaryEnabled,
        monthlyReportEnabled: monthlyReportEnabled,
        securityAlertsEnabled: securityAlertsEnabled,
        productUpdatesEnabled: productUpdatesEnabled,
      );
      await _write('notifications', synced.toJson());
      await _setPending('notifications', false);
      return synced;
    } catch (error, stackTrace) {
      _logFallback('sync notification preferences', error, stackTrace);
      return local;
    }
  }

  Future<PrivacyPreferences> privacyPreferences() async {
    final local = await _read(
      'privacy',
      PrivacyPreferences.fromJson,
      defaultPrivacyPreferences,
    );
    if (_localOnly) return local;
    if (await _isPending('privacy')) {
      try {
        final synced = await _api.updatePrivacyPreferences(
          revision: local.revision,
          policyVersion: local.policyVersion,
          personalizedInsights: local.personalizedInsights,
          anonymousAnalytics: local.anonymousAnalytics,
        );
        await _write('privacy', synced.toJson());
        await _setPending('privacy', false);
        return synced;
      } catch (error, stackTrace) {
        _logFallback('retry privacy preferences', error, stackTrace);
        return local;
      }
    }
    try {
      final value = await _api.getPrivacyPreferences();
      await _write('privacy', value.toJson());
      return value;
    } catch (error, stackTrace) {
      _logFallback('load privacy preferences', error, stackTrace);
      return local;
    }
  }

  Future<PrivacyPreferences> updatePrivacyPreferences({
    required PrivacyPreferences current,
    bool? personalizedInsights,
    bool? anonymousAnalytics,
  }) async {
    final local = current.copyWith(
      personalizedInsights: personalizedInsights,
      anonymousAnalytics: anonymousAnalytics,
    );
    await _write('privacy', local.toJson());
    if (_localOnly) {
      await _setPending('privacy', false);
      return local;
    }
    await _setPending('privacy', true);
    try {
      final synced = await _api.updatePrivacyPreferences(
        revision: current.revision,
        policyVersion: current.policyVersion,
        personalizedInsights: personalizedInsights,
        anonymousAnalytics: anonymousAnalytics,
      );
      await _write('privacy', synced.toJson());
      await _setPending('privacy', false);
      return synced;
    } catch (error, stackTrace) {
      _logFallback('sync privacy preferences', error, stackTrace);
      return local;
    }
  }

  Future<SyncStatus> syncStatus() async {
    if (_localOnly) {
      return const SyncStatus(status: 'device-linked', serverRevision: 0);
    }
    try {
      return await _api.syncStatus();
    } catch (error, stackTrace) {
      _logFallback('load sync status', error, stackTrace);
      return const SyncStatus(status: 'local', serverRevision: 0);
    }
  }

  Future<List<FaqArticle>> faqs({String locale = 'en'}) async {
    try {
      final remote = await _api.faqs(locale: locale);
      return remote.isEmpty ? builtInFaqs : remote;
    } catch (error, stackTrace) {
      _logFallback('load FAQs', error, stackTrace);
      return builtInFaqs;
    }
  }

  Future<void> migrateLocalSettingsTo(String targetAccountScope) async {
    final target = targetAccountScope.trim().toLowerCase();
    if (target.isEmpty || target == _accountScope) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      for (final name in const ['account', 'notifications', 'privacy']) {
        final value = preferences.getString(_key(name));
        if (value == null) continue;
        final targetKey = 'account_settings.$target.$name';
        await preferences.setString(targetKey, value);
        await preferences.setBool('$targetKey.pending', true);
      }
    } catch (error, stackTrace) {
      _logFallback('migrate guest settings', error, stackTrace);
    }
  }

  Future<void> markLocalSettingsForSync() async {
    for (final name in const ['account', 'notifications', 'privacy']) {
      await _setPending(name, true);
    }
  }

  Future<T> _read<T>(
    String name,
    T Function(Map<String, dynamic>) fromJson,
    T fallback,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key(name));
      if (raw == null) return fallback;
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error, stackTrace) {
      _logFallback('read local $name settings', error, stackTrace);
      return fallback;
    }
  }

  Future<void> _write(String name, Map<String, dynamic> value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_key(name), jsonEncode(value));
    } catch (error, stackTrace) {
      _logFallback('write local $name settings', error, stackTrace);
    }
  }

  Future<bool> _isPending(String name) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool('${_key(name)}.pending') ?? false;
    } catch (error, stackTrace) {
      _logFallback('read local $name sync state', error, stackTrace);
      return false;
    }
  }

  Future<void> _setPending(String name, bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('${_key(name)}.pending', value);
    } catch (error, stackTrace) {
      _logFallback('write local $name sync state', error, stackTrace);
    }
  }

  String _key(String name) => 'account_settings.$_accountScope.$name';

  void _logFallback(String operation, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    if (error is DioException) {
      debugPrint(
        '[settings] operation="$operation" fallback=local '
        'method=${error.requestOptions.method} '
        'url=${error.requestOptions.uri} '
        'status=${error.response?.statusCode ?? 'none'} '
        'type=${error.type.name}',
      );
      return;
    }
    debugPrint(
      '[settings] operation="$operation" fallback=local '
      'error=${error.runtimeType}: $error',
    );
  }
}
