import 'dart:typed_data';

class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.status,
    required this.revision,
    this.pendingEmail,
    this.emailVerifiedAt,
    this.phone,
    this.avatarUrl,
  });

  final int id;
  final String fullName;
  final String username;
  final String email;
  final String status;
  final int revision;
  final String? pendingEmail;
  final DateTime? emailVerifiedAt;
  final String? phone;
  final String? avatarUrl;

  factory AccountProfile.fromJson(Map<String, dynamic> json) => AccountProfile(
    id: (json['id'] as num).toInt(),
    fullName: json['fullName'] as String? ?? '',
    username: json['username'] as String? ?? '',
    email: json['email'] as String? ?? '',
    status: json['status'] as String? ?? 'active',
    revision: (json['revision'] as num?)?.toInt() ?? 0,
    pendingEmail: json['pendingEmail'] as String?,
    emailVerifiedAt: _date(json['emailVerifiedAt']),
    phone: json['phone'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
  );
}

class AccountPreferences {
  const AccountPreferences({
    required this.currencyCode,
    required this.languageCode,
    required this.regionCode,
    required this.timeZone,
    required this.themeMode,
    required this.revision,
  });

  final String currencyCode;
  final String languageCode;
  final String regionCode;
  final String timeZone;
  final String themeMode;
  final int revision;

  AccountPreferences copyWith({
    String? currencyCode,
    String? languageCode,
    String? regionCode,
    String? timeZone,
    String? themeMode,
    int? revision,
  }) => AccountPreferences(
    currencyCode: currencyCode ?? this.currencyCode,
    languageCode: languageCode ?? this.languageCode,
    regionCode: regionCode ?? this.regionCode,
    timeZone: timeZone ?? this.timeZone,
    themeMode: themeMode ?? this.themeMode,
    revision: revision ?? this.revision,
  );

  Map<String, dynamic> toJson() => {
    'currencyCode': currencyCode,
    'languageCode': languageCode,
    'regionCode': regionCode,
    'timeZone': timeZone,
    'themeMode': themeMode,
    'revision': revision,
  };

  factory AccountPreferences.fromJson(Map<String, dynamic> json) =>
      AccountPreferences(
        currencyCode: json['currencyCode'] as String? ?? 'IDR',
        languageCode: json['languageCode'] as String? ?? 'en',
        regionCode: json['regionCode'] as String? ?? 'ID',
        timeZone: json['timeZone'] as String? ?? 'Asia/Jakarta',
        themeMode: json['themeMode'] as String? ?? 'light',
        revision: (json['revision'] as num?)?.toInt() ?? 0,
      );
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.spendingReminderEnabled,
    required this.reminderTime,
    required this.weeklySummaryEnabled,
    required this.monthlyReportEnabled,
    required this.securityAlertsEnabled,
    required this.productUpdatesEnabled,
    required this.revision,
  });

  final bool spendingReminderEnabled;
  final String reminderTime;
  final bool weeklySummaryEnabled;
  final bool monthlyReportEnabled;
  final bool securityAlertsEnabled;
  final bool productUpdatesEnabled;
  final int revision;

  NotificationPreferences copyWith({
    bool? spendingReminderEnabled,
    String? reminderTime,
    bool? weeklySummaryEnabled,
    bool? monthlyReportEnabled,
    bool? securityAlertsEnabled,
    bool? productUpdatesEnabled,
    int? revision,
  }) => NotificationPreferences(
    spendingReminderEnabled:
        spendingReminderEnabled ?? this.spendingReminderEnabled,
    reminderTime: reminderTime ?? this.reminderTime,
    weeklySummaryEnabled: weeklySummaryEnabled ?? this.weeklySummaryEnabled,
    monthlyReportEnabled: monthlyReportEnabled ?? this.monthlyReportEnabled,
    securityAlertsEnabled: securityAlertsEnabled ?? this.securityAlertsEnabled,
    productUpdatesEnabled: productUpdatesEnabled ?? this.productUpdatesEnabled,
    revision: revision ?? this.revision,
  );

  Map<String, dynamic> toJson() => {
    'spendingReminderEnabled': spendingReminderEnabled,
    'reminderTime': reminderTime,
    'weeklySummaryEnabled': weeklySummaryEnabled,
    'monthlyReportEnabled': monthlyReportEnabled,
    'securityAlertsEnabled': securityAlertsEnabled,
    'productUpdatesEnabled': productUpdatesEnabled,
    'revision': revision,
  };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        spendingReminderEnabled:
            json['spendingReminderEnabled'] as bool? ?? true,
        reminderTime: json['reminderTime'] as String? ?? '20:00:00',
        weeklySummaryEnabled: json['weeklySummaryEnabled'] as bool? ?? true,
        monthlyReportEnabled: json['monthlyReportEnabled'] as bool? ?? true,
        securityAlertsEnabled: json['securityAlertsEnabled'] as bool? ?? true,
        productUpdatesEnabled: json['productUpdatesEnabled'] as bool? ?? false,
        revision: (json['revision'] as num?)?.toInt() ?? 0,
      );
}

class PrivacyPreferences {
  const PrivacyPreferences({
    required this.personalizedInsights,
    required this.anonymousAnalytics,
    required this.policyVersion,
    required this.revision,
  });

  final bool personalizedInsights;
  final bool anonymousAnalytics;
  final String policyVersion;
  final int revision;

  PrivacyPreferences copyWith({
    bool? personalizedInsights,
    bool? anonymousAnalytics,
    String? policyVersion,
    int? revision,
  }) => PrivacyPreferences(
    personalizedInsights: personalizedInsights ?? this.personalizedInsights,
    anonymousAnalytics: anonymousAnalytics ?? this.anonymousAnalytics,
    policyVersion: policyVersion ?? this.policyVersion,
    revision: revision ?? this.revision,
  );

  Map<String, dynamic> toJson() => {
    'personalizedInsights': personalizedInsights,
    'anonymousAnalytics': anonymousAnalytics,
    'policyVersion': policyVersion,
    'revision': revision,
  };

  factory PrivacyPreferences.fromJson(Map<String, dynamic> json) =>
      PrivacyPreferences(
        personalizedInsights: json['personalizedInsights'] as bool? ?? true,
        anonymousAnalytics: json['anonymousAnalytics'] as bool? ?? true,
        policyVersion: json['policyVersion'] as String? ?? '2026-01',
        revision: (json['revision'] as num?)?.toInt() ?? 0,
      );
}

class SyncStatus {
  const SyncStatus({
    required this.status,
    required this.serverRevision,
    this.lastSyncedAt,
  });

  final String status;
  final DateTime? lastSyncedAt;
  final int serverRevision;

  factory SyncStatus.fromJson(Map<String, dynamic> json) => SyncStatus(
    status: json['status'] as String? ?? 'unknown',
    lastSyncedAt: _date(json['lastSyncedAt']),
    serverRevision: (json['serverRevision'] as num?)?.toInt() ?? 0,
  );
}

class AccountSession {
  const AccountSession({
    required this.id,
    required this.current,
    required this.lastActiveAt,
    required this.expiresAt,
    required this.revokedAt,
    this.deviceName,
    this.userAgent,
  });

  final String id;
  final bool current;
  final String? deviceName;
  final String? userAgent;
  final DateTime? lastActiveAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;

  bool get active =>
      revokedAt == null && (expiresAt?.isAfter(DateTime.now()) ?? false);

  factory AccountSession.fromJson(Map<String, dynamic> json) => AccountSession(
    id: json['id'] as String,
    current: json['current'] as bool? ?? false,
    deviceName: json['deviceName'] as String?,
    userAgent: json['userAgent'] as String?,
    lastActiveAt: _date(json['lastActiveAt']),
    expiresAt: _date(json['expiresAt']),
    revokedAt: _date(json['revokedAt']),
  );
}

class FaqArticle {
  const FaqArticle({
    required this.id,
    required this.locale,
    required this.category,
    required this.title,
    required this.body,
  });

  final String id;
  final String locale;
  final String category;
  final String title;
  final String body;

  factory FaqArticle.fromJson(Map<String, dynamic> json) => FaqArticle(
    id: json['id'] as String,
    locale: json['locale'] as String? ?? 'en',
    category: json['category'] as String? ?? 'general',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
  );
}

class SupportTicket {
  const SupportTicket({required this.id, required this.status});

  final String id;
  final String status;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: json['id'] as String,
    status: json['status'] as String? ?? 'open',
  );
}

class DataExportJob {
  const DataExportJob({
    required this.jobId,
    required this.status,
    this.downloadUrl,
    this.failureReason,
  });

  final String jobId;
  final String status;
  final String? downloadUrl;
  final String? failureReason;

  factory DataExportJob.fromJson(Map<String, dynamic> json) => DataExportJob(
    jobId: json['jobId'] as String,
    status: json['status'] as String? ?? 'queued',
    downloadUrl: json['downloadUrl'] as String?,
    failureReason: json['failureReason'] as String?,
  );
}

class DownloadedExport {
  const DownloadedExport(this.bytes, this.fileName);

  final Uint8List bytes;
  final String fileName;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
