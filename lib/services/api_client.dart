import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense_summary.dart';
import '../models/account_settings.dart';
import '../models/session.dart';
import '../models/transaction.dart';
import '../models/transaction_sync.dart';
import 'session_store.dart';

class GuestAiTrialLimitException implements Exception {
  const GuestAiTrialLimitException({this.message});
  static const code = 'GUEST_AI_LIMIT_REACHED';
  final String? message;
}

class NotificationCaptureProvision {
  const NotificationCaptureProvision({
    required this.deviceId,
    required this.captureCredential,
    required this.enabledAt,
  });

  final String deviceId;
  final String captureCredential;
  final DateTime enabledAt;

  factory NotificationCaptureProvision.fromJson(Map<String, dynamic> json) =>
      NotificationCaptureProvision(
        deviceId: json['deviceId'] as String,
        captureCredential: json['captureCredential'] as String,
        enabledAt: DateTime.parse(json['enabledAt'] as String),
      );
}

class ApiClient {
  ApiClient(this._sessions, {Dio? dio, void Function()? onUnauthorized})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.requestOptions.extra[_skipUnauthorizedHandling] == true) {
            handler.next(error);
            return;
          }
          final wasAuthenticated = error.requestOptions.headers.keys.any(
            (key) => key.toLowerCase() == 'authorization',
          );
          if (wasAuthenticated && error.response?.statusCode == 401) {
            final requestToken = _bearerToken(error.requestOptions);
            final activeSession = await _sessions.read();
            if (requestToken != null &&
                activeSession?.token == requestToken &&
                await _tokenIsInvalid(error.requestOptions, requestToken)) {
              // Re-read after validation so a late response from an older
              // request can never erase a newly saved login session.
              final latestSession = await _sessions.read();
              if (latestSession?.token == requestToken) {
                await _sessions.markReauthenticationRequired();
                onUnauthorized?.call();
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static const defaultBaseUrl = 'http://202.10.45.149/api/v1/';
  static const _skipUnauthorizedHandling = 'skipUnauthorizedHandling';
  final SessionStore _sessions;
  final Dio _dio;
  Future<bool>? _sessionValidation;
  String? _sessionValidationToken;

  String? _bearerToken(RequestOptions request) {
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() != 'authorization') continue;
      final value = entry.value?.toString() ?? '';
      if (value.startsWith('Bearer ') && value.length > 7) {
        return value.substring(7);
      }
    }
    return null;
  }

  Future<bool> _tokenIsInvalid(
    RequestOptions failedRequest,
    String token,
  ) async {
    if (failedRequest.path.endsWith('/auth/me')) return true;
    if (_sessionValidationToken == token && _sessionValidation != null) {
      return _sessionValidation!;
    }

    _sessionValidationToken = token;
    final validation = _validateToken(token);
    _sessionValidation = validation;
    try {
      return await validation;
    } finally {
      if (identical(_sessionValidation, validation)) {
        _sessionValidation = null;
        _sessionValidationToken = null;
      }
    }
  }

  Future<bool> _validateToken(String token) async {
    try {
      await _dio.get(
        '${await _base}auth/me',
        options: _authorizationOptions(
          token,
          extra: {_skipUnauthorizedHandling: true},
        ),
      );
      return false;
    } on DioException catch (error) {
      // Only an explicit rejection from the session endpoint signs the user
      // out. Endpoint-specific 401s and network failures keep the session.
      return error.response?.statusCode == 401;
    }
  }

  Future<String> get _base async {
    final preferences = await SharedPreferences.getInstance();
    final url = preferences.getString('base_url') ?? defaultBaseUrl;
    return url.endsWith('/') ? url : '$url/';
  }

  Future<String> resolvedBaseUrl() => _base;

  Future<Options> _options() async {
    final session = await _sessions.read();
    if (session == null || !session.canAuthenticate) {
      throw StateError('Sign in to sync changes saved on this device.');
    }
    return _authorizationOptions(session.token);
  }

  Options _authorizationOptions(String token, {Map<String, dynamic>? extra}) =>
      Options(
        headers: {'Authorization': 'Bearer $token'},
        // The connected API gateway currently treats this header name as
        // case-sensitive. Dio otherwise writes it as lowercase on dart:io.
        preserveHeaderCase: true,
        extra: extra,
      );

  Future<Session> login(String username, String password) async {
    final response = await _dio.post(
      '${await _base}auth/login',
      data: {'username': username.trim(), 'password': password},
    );
    return _sessionFromResponse(
      response.data as Map<String, dynamic>,
      fallbackUsername: username.trim(),
    );
  }

  Future<Session> guestLogin() async {
    final existing = await _sessions.ensureOfflineGuestIdentity();
    if (existing?.isGuest == true && existing!.canAuthenticate) {
      return existing;
    }
    final response = await _dio.post(
      '${await _base}auth/guest-login',
      data: existing?.clientGuestId == null
          ? null
          : {
              'clientGuestId': existing!.clientGuestId,
              'installationCredential': existing.installationCredential,
            },
    );
    return _sessionFromResponse(
      response.data as Map<String, dynamic>,
      preserveLocalIdentity: existing,
    );
  }

  Future<SyncPushResponse> pushTransactions({
    required String deviceId,
    required List<TransactionMutation> operations,
  }) async {
    final response = await _dio.post(
      '${await _base}sync/push',
      data: {
        'deviceId': deviceId,
        'operations': operations.map((item) => item.toJson()).toList(),
      },
      options: await _options(),
    );
    return SyncPushResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SyncPullResponse> pullTransactions({
    String? cursor,
    int limit = 100,
  }) async {
    final response = await _dio.get(
      '${await _base}sync/pull',
      queryParameters: {'cursor': ?cursor, 'limit': limit},
      options: await _options(),
    );
    return SyncPullResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    bool preserveGuest = false,
  }) async {
    await _dio.post(
      '${await _base}auth/register',
      data: {
        'fullName': fullName.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
      },
      options: preserveGuest ? await _options() : null,
    );
  }

  Future<Session> upgradeGuest({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '${await _base}auth/upgrade-guest',
      data: {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
      },
      options: await _options(),
    );
    return _sessionFromResponse(response.data as Map<String, dynamic>);
  }

  Future<Session> mergeGuest({
    required String username,
    required String password,
  }) async {
    final existing = await _sessions.read();
    final response = await _dio.post(
      '${await _base}auth/merge-guest',
      data: {'username': username.trim(), 'password': password},
      options: await _options(),
    );
    return _sessionFromResponse(
      response.data as Map<String, dynamic>,
      fallbackUsername: username.trim(),
      preserveLocalIdentity: existing,
    );
  }

  Future<ExpenseSummary> summary(DateTime month) async {
    final response = await _dio.get(
      '${await _base}expense/summary',
      queryParameters: {'month': month.month, 'year': month.year},
      options: await _options(),
    );
    return ExpenseSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Transaction>> history(DateTime month) async {
    final response = await _dio.get(
      '${await _base}expense/history',
      queryParameters: {'month': month.month, 'year': month.year},
      options: await _options(),
    );
    return (response.data as List)
        .map((item) => Transaction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Transaction>> recentTransactions() async {
    final response = await _dio.get(
      '${await _base}expense/recent',
      options: await _options(),
    );
    return (response.data as List)
        .map((item) => Transaction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Transaction> notification(String text) async {
    try {
      final response = await _dio.post(
        '${await _base}expense/notification',
        data: {'text': text.trim()},
        options: await _options(),
      );
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      _throwIfGuestLimit(error);
      rethrow;
    }
  }

  Future<NotificationCaptureProvision> provisionNotificationCaptureDevice({
    String? deviceId,
  }) async {
    final response = await _dio.post(
      '${await _base}me/notification-capture-devices',
      data: {
        'deviceId': ?deviceId,
        'platform': 'android',
        'deviceName': 'Android device',
        'appVersion': '1.0.0',
      },
      options: await _options(),
    );
    final json = response.data as Map<String, dynamic>;
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return NotificationCaptureProvision.fromJson(data);
  }

  Future<void> revokeNotificationCaptureDevice(String deviceId) async {
    await _dio.delete(
      '${await _base}me/notification-capture-devices/${Uri.encodeComponent(deviceId)}',
      options: await _options(),
    );
  }

  Future<Transaction> receipt(File file) async {
    try {
      final response = await _dio.post(
        '${await _base}expense/receipt',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path),
        }),
        options: await _options(),
      );
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      _throwIfGuestLimit(error);
      rethrow;
    }
  }

  Future<int> remainingAiTrials() async {
    final response = await _dio.get(
      '${await _base}auth/me',
      options: await _options(),
    );
    return ((response.data as Map<String, dynamic>)['remaining_ai_trials']
                as num?)
            ?.toInt() ??
        0;
  }

  Future<Transaction> createManualTransaction({
    required DateTime date,
    required double amount,
    required String category,
    required String paymentMethod,
    required String description,
  }) async {
    final response = await _dio.post(
      '${await _base}expense/manual',
      data: _expensePayload(date, amount, category, paymentMethod, description),
      options: await _options(),
    );
    return Transaction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Transaction> updateTransaction({
    required int id,
    required DateTime date,
    required double amount,
    required String category,
    required String paymentMethod,
    required String description,
  }) async {
    final response = await _dio.put(
      '${await _base}expense/$id',
      data: _expensePayload(date, amount, category, paymentMethod, description),
      options: await _options(),
    );
    return Transaction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteTransaction(int id) async {
    await _dio.delete('${await _base}expense/$id', options: await _options());
  }

  Future<AccountProfile> getProfile() async {
    final response = await _dio.get(
      '${await _base}me',
      options: await _options(),
    );
    return AccountProfile.fromJson(_envelopeData(response.data));
  }

  Future<AccountProfile> updateProfile({
    required int revision,
    String? fullName,
    String? username,
    String? phone,
  }) async {
    final response = await _dio.patch(
      '${await _base}me',
      data: {
        if (fullName != null) 'fullName': fullName.trim(),
        if (username != null) 'username': username.trim(),
        if (phone != null) 'phone': phone.trim(),
      },
      options: await _revisionOptions(revision),
    );
    return AccountProfile.fromJson(_envelopeData(response.data));
  }

  Future<bool> usernameAvailable(String username) async {
    final response = await _dio.get(
      '${await _base}usernames/${Uri.encodeComponent(username.trim())}/availability',
      options: await _options(),
    );
    return _envelopeData(response.data)['available'] as bool? ?? false;
  }

  Future<AccountProfile> uploadAvatar(File file) async {
    final bytes = await file.readAsBytes();
    final contentType = _imageContentType(file.path);
    final ticketResponse = await _dio.post(
      '${await _base}me/avatar/upload-url',
      data: {'contentType': contentType, 'sizeBytes': bytes.length},
      options: await _options(),
    );
    final ticket = _envelopeData(ticketResponse.data);
    final uploadUrl = ticket['uploadUrl'] as String;
    await _dio.put(
      await _absoluteUrl(uploadUrl),
      data: bytes,
      options: (await _options()).copyWith(
        headers: {
          ...(await _options()).headers ?? <String, dynamic>{},
          'Content-Type': contentType,
        },
      ),
    );
    return getProfile();
  }

  Future<Uint8List> avatarContent() async {
    final response = await _dio.get<List<int>>(
      '${await _base}me/avatar/content',
      options: (await _options()).copyWith(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  Future<AccountProfile> deleteAvatar() async {
    final response = await _dio.delete(
      '${await _base}me/avatar',
      options: await _options(),
    );
    return AccountProfile.fromJson(_envelopeData(response.data));
  }

  Future<String> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    final response = await _dio.post(
      '${await _base}me/email-change',
      data: {'newEmail': newEmail.trim(), 'currentPassword': currentPassword},
      options: await _options(),
    );
    return _envelopeData(response.data)['pendingEmail'] as String;
  }

  Future<AccountProfile> verifyEmailChange(String verificationToken) async {
    final response = await _dio.post(
      '${await _base}me/email-change/verify',
      data: {'verificationToken': verificationToken.trim()},
      options: await _options(),
    );
    return AccountProfile.fromJson(_envelopeData(response.data));
  }

  Future<int> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _dio.post(
      '${await _base}me/password/change',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'retainCurrentSession': true,
      },
      options: await _options(),
    );
    return (_envelopeData(response.data)['revokedSessionCount'] as num?)
            ?.toInt() ??
        0;
  }

  Future<List<AccountSession>> sessions() async {
    final response = await _dio.get(
      '${await _base}me/sessions',
      queryParameters: {'page': 0, 'size': 100},
      options: await _options(),
    );
    final json = response.data as Map<String, dynamic>;
    return (json['data'] as List<dynamic>? ?? const [])
        .map((item) => AccountSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> revokeSession(String sessionId) async {
    await _dio.delete(
      '${await _base}me/sessions/${Uri.encodeComponent(sessionId)}',
      options: await _options(),
    );
  }

  Future<void> revokeOtherSessions() async {
    await _dio.delete(
      '${await _base}me/sessions/others',
      options: await _options(),
    );
  }

  Future<AccountPreferences> getPreferences() async {
    final response = await _dio.get(
      '${await _base}me/preferences',
      options: await _options(),
    );
    return AccountPreferences.fromJson(_envelopeData(response.data));
  }

  Future<AccountPreferences> updatePreferences({
    required int revision,
    String? currencyCode,
    String? languageCode,
    String? regionCode,
    String? timeZone,
    String? themeMode,
  }) async {
    final response = await _dio.patch(
      '${await _base}me/preferences',
      data: {
        'currencyCode': ?currencyCode,
        'languageCode': ?languageCode,
        'regionCode': ?regionCode,
        'timeZone': ?timeZone,
        'themeMode': ?themeMode,
      },
      options: await _revisionOptions(revision),
    );
    return AccountPreferences.fromJson(_envelopeData(response.data));
  }

  Future<NotificationPreferences> getNotificationPreferences() async {
    final response = await _dio.get(
      '${await _base}me/notification-preferences',
      options: await _options(),
    );
    return NotificationPreferences.fromJson(_envelopeData(response.data));
  }

  Future<NotificationPreferences> updateNotificationPreferences({
    required int revision,
    bool? spendingReminderEnabled,
    String? reminderTime,
    bool? weeklySummaryEnabled,
    bool? monthlyReportEnabled,
    bool? securityAlertsEnabled,
    bool? productUpdatesEnabled,
  }) async {
    final response = await _dio.patch(
      '${await _base}me/notification-preferences',
      data: {
        'spendingReminderEnabled': ?spendingReminderEnabled,
        'reminderTime': ?reminderTime,
        'weeklySummaryEnabled': ?weeklySummaryEnabled,
        'monthlyReportEnabled': ?monthlyReportEnabled,
        'securityAlertsEnabled': ?securityAlertsEnabled,
        'productUpdatesEnabled': ?productUpdatesEnabled,
      },
      options: await _revisionOptions(revision),
    );
    return NotificationPreferences.fromJson(_envelopeData(response.data));
  }

  Future<PrivacyPreferences> getPrivacyPreferences() async {
    final response = await _dio.get(
      '${await _base}me/privacy-preferences',
      options: await _options(),
    );
    return PrivacyPreferences.fromJson(_envelopeData(response.data));
  }

  Future<PrivacyPreferences> updatePrivacyPreferences({
    required int revision,
    required String policyVersion,
    bool? personalizedInsights,
    bool? anonymousAnalytics,
  }) async {
    final response = await _dio.patch(
      '${await _base}me/privacy-preferences',
      data: {
        'personalizedInsights': ?personalizedInsights,
        'anonymousAnalytics': ?anonymousAnalytics,
        'policyVersion': policyVersion,
        'sourcePlatform': Platform.isIOS ? 'ios' : 'android',
      },
      options: await _revisionOptions(revision),
    );
    return PrivacyPreferences.fromJson(_envelopeData(response.data));
  }

  Future<SyncStatus> syncStatus() async {
    final response = await _dio.get(
      '${await _base}me/sync-status',
      options: await _options(),
    );
    return SyncStatus.fromJson(_envelopeData(response.data));
  }

  Future<DataExportJob> requestDataExport() async {
    final response = await _dio.post(
      '${await _base}me/data-exports',
      options: await _idempotentOptions(),
    );
    return DataExportJob.fromJson(_envelopeData(response.data));
  }

  Future<DataExportJob> dataExport(String jobId) async {
    final response = await _dio.get(
      '${await _base}me/data-exports/${Uri.encodeComponent(jobId)}',
      options: await _options(),
    );
    return DataExportJob.fromJson(_envelopeData(response.data));
  }

  Future<DownloadedExport> downloadDataExport(DataExportJob job) async {
    if (job.downloadUrl == null) throw StateError('The export is not ready.');
    final response = await _dio.get<List<int>>(
      await _absoluteUrl(job.downloadUrl!),
      options: (await _options()).copyWith(responseType: ResponseType.bytes),
    );
    return DownloadedExport(
      Uint8List.fromList(response.data ?? const []),
      'broke-ai-data-export-${job.jobId}.zip',
    );
  }

  Future<int> clearTransactions(String currentPassword) async {
    final response = await _dio.post(
      '${await _base}me/transactions/clear',
      data: {'confirmation': 'CLEAR', 'currentPassword': currentPassword},
      options: await _idempotentOptions(),
    );
    return (_envelopeData(response.data)['deletedCount'] as num?)?.toInt() ?? 0;
  }

  Future<int> clearGuestTransactions() async {
    final response = await _dio.post(
      '${await _base}guest/transactions/clear',
      data: {'confirmation': 'CLEAR'},
      options: await _idempotentOptions(),
    );
    return (_envelopeData(response.data)['deletedCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> deleteGuestAccount() async {
    await _dio.delete(
      '${await _base}guest-account',
      data: {'confirmation': 'DELETE'},
      options: await _idempotentOptions(),
    );
  }

  Future<DateTime?> requestAccountDeletion(String currentPassword) async {
    final response = await _dio.post(
      '${await _base}me/deletion-request',
      data: {'confirmation': 'DELETE', 'currentPassword': currentPassword},
      options: await _idempotentOptions(),
    );
    return DateTime.tryParse(
      _envelopeData(response.data)['scheduledFor'] as String? ?? '',
    );
  }

  Future<List<FaqArticle>> faqs({String locale = 'en'}) async {
    final response = await _dio.get(
      '${await _base}support/faqs',
      queryParameters: {'locale': locale, 'page': 0, 'size': 100},
      options: await _options(),
    );
    final json = response.data as Map<String, dynamic>;
    return (json['data'] as List<dynamic>? ?? const [])
        .map((item) => FaqArticle.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SupportTicket> createSupportTicket({
    required bool bug,
    required String subject,
    required String message,
    String currentRoute = '/profile/help',
  }) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    final response = await _dio.post(
      '${await _base}support/tickets',
      data: {
        'type': bug ? 'bug' : 'support',
        'subject': subject.trim(),
        'message': message.trim(),
        'appVersion': '1.0.0',
        'platform': platform,
        'osVersion': _limit(Platform.operatingSystemVersion, 60),
        'deviceModel': '${Platform.operatingSystem} device',
        'locale': Intl.getCurrentLocale(),
        'currentRoute': currentRoute,
      },
      options: await _options(),
    );
    return SupportTicket.fromJson(_envelopeData(response.data));
  }

  Map<String, dynamic> _expensePayload(
    DateTime date,
    double amount,
    String category,
    String paymentMethod,
    String description,
  ) => {
    'date': DateFormat('yyyy-MM-dd').format(date),
    'amount': amount,
    'category': category.trim(),
    'paymentMethod': paymentMethod.trim(),
    'description': description.trim(),
  };

  Future<Options> _revisionOptions(int revision) async {
    final authenticated = await _options();
    return authenticated.copyWith(
      headers: {...?authenticated.headers, 'If-Match': '"$revision"'},
    );
  }

  Future<Options> _idempotentOptions() async {
    final authenticated = await _options();
    return authenticated.copyWith(
      headers: {
        ...?authenticated.headers,
        'Idempotency-Key': _idempotencyKey(),
      },
    );
  }

  Map<String, dynamic> _envelopeData(Object? value) {
    final envelope = value as Map<String, dynamic>;
    return envelope['data'] as Map<String, dynamic>;
  }

  Future<String> _absoluteUrl(String url) async {
    if (Uri.tryParse(url)?.hasScheme == true) return url;
    return Uri.parse(await _base).resolve(url).toString();
  }

  String _imageContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _idempotencyKey() {
    final random = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}';
  }

  String _limit(String value, int length) =>
      value.length <= length ? value : value.substring(0, length);

  Session _sessionFromResponse(
    Map<String, dynamic> json, {
    String? fallbackUsername,
    Session? preserveLocalIdentity,
  }) {
    final user = json['user'] as Map<String, dynamic>?;
    return Session(
      token: json['token'] as String,
      expiresAt: DateTime.now().add(
        Duration(seconds: (json['expiresIn'] as num).toInt()),
      ),
      username: json['username'] as String? ?? fallbackUsername ?? 'guest',
      isGuest: json['isGuest'] as bool? ?? false,
      accountId: json['accountId'] as String?,
      localScopeId:
          preserveLocalIdentity?.accountScope ??
          json['accountId'] as String? ??
          fallbackUsername,
      clientGuestId: preserveLocalIdentity?.clientGuestId,
      installationCredential: preserveLocalIdentity?.installationCredential,
      refreshAvailable: json['refresh_available'] as bool? ?? false,
      remainingAiTrials: (json['remaining_ai_trials'] as num?)?.toInt() ?? 0,
      fullName: user?['fullName'] as String? ?? preserveLocalIdentity?.fullName,
      email: user?['email'] as String? ?? preserveLocalIdentity?.email,
    );
  }

  void _throwIfGuestLimit(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['code'] == GuestAiTrialLimitException.code) {
      throw GuestAiTrialLimitException(message: data['message'] as String?);
    }
  }
}

String apiErrorMessage(Object error) {
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map) {
      final contractError = body['error'];
      if (contractError is Map && contractError['message'] is String) {
        return contractError['message'] as String;
      }
      if (body['message'] is String) return body['message'] as String;
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Unable to reach the server. Check your connection and try again.';
    }
  }
  if (error is StateError) return error.message;
  return 'Something went wrong. Please try again.';
}
