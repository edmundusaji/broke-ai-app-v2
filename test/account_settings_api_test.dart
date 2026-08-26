import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/services/api_client.dart';
import 'package:broke_ai_app/services/session_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SessionStore store;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'base_url': 'https://example.test/api/v1/',
    });
    store = SessionStore();
    await store.save(
      Session(
        token: 'account-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        username: 'edmund',
        isGuest: false,
      ),
    );
  });

  test('profile update follows the revision-safe backend contract', () async {
    final adapter = _JsonAdapter({
      'data': {
        'id': 1,
        'fullName': 'Edmund Aji',
        'username': 'edmund',
        'email': 'edmund@example.com',
        'phone': '+6281234567890',
        'status': 'active',
        'revision': 5,
      },
      'meta': {'requestId': 'request-id'},
    });
    final api = ApiClient(store, dio: Dio()..httpClientAdapter = adapter);

    final profile = await api.updateProfile(
      revision: 4,
      fullName: 'Edmund Aji',
      username: 'edmund',
      phone: '+6281234567890',
    );

    expect(adapter.request?.method, 'PATCH');
    expect(adapter.request?.path, 'https://example.test/api/v1/me');
    expect(adapter.request?.headers['Authorization'], 'Bearer account-token');
    expect(adapter.request?.preserveHeaderCase, isTrue);
    expect(adapter.request?.headers['If-Match'], '"4"');
    expect(adapter.request?.data, {
      'fullName': 'Edmund Aji',
      'username': 'edmund',
      'phone': '+6281234567890',
    });
    expect(profile.revision, 5);
  });

  test('preference updates use backend field names and If-Match', () async {
    final adapter = _JsonAdapter({
      'data': {
        'currencyCode': 'USD',
        'languageCode': 'en',
        'regionCode': 'US',
        'timeZone': 'America/New_York',
        'themeMode': 'dark',
        'revision': 3,
      },
      'meta': {'requestId': 'request-id'},
    });
    final api = ApiClient(store, dio: Dio()..httpClientAdapter = adapter);

    final preferences = await api.updatePreferences(
      revision: 2,
      currencyCode: 'USD',
      regionCode: 'US',
      timeZone: 'America/New_York',
      themeMode: 'dark',
    );

    expect(adapter.request?.path, 'https://example.test/api/v1/me/preferences');
    expect(adapter.request?.headers['If-Match'], '"2"');
    expect(adapter.request?.data, {
      'currencyCode': 'USD',
      'regionCode': 'US',
      'timeZone': 'America/New_York',
      'themeMode': 'dark',
    });
    expect(preferences.themeMode, 'dark');
  });

  test('destructive requests include confirmation and idempotency', () async {
    final adapter = _JsonAdapter({
      'data': {'deletedCount': 12, 'recoverableUntil': '2026-08-20T00:00:00Z'},
      'meta': {'requestId': 'request-id'},
    });
    final api = ApiClient(store, dio: Dio()..httpClientAdapter = adapter);

    final count = await api.clearTransactions('correct horse battery staple');

    expect(
      adapter.request?.path,
      'https://example.test/api/v1/me/transactions/clear',
    );
    expect(adapter.request?.headers['Idempotency-Key'], isNotEmpty);
    expect(adapter.request?.data, {
      'confirmation': 'CLEAR',
      'currentPassword': 'correct horse battery staple',
    });
    expect(count, 12);
  });

  test('guest transaction clear follows the planned guest contract', () async {
    final adapter = _JsonAdapter({
      'data': {'deletedCount': 4},
      'meta': {'requestId': 'request-id'},
    });
    final api = ApiClient(store, dio: Dio()..httpClientAdapter = adapter);

    final count = await api.clearGuestTransactions();

    expect(
      adapter.request?.path,
      'https://example.test/api/v1/guest/transactions/clear',
    );
    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.headers['Authorization'], 'Bearer account-token');
    expect(adapter.request?.headers['Idempotency-Key'], isNotEmpty);
    expect(adapter.request?.data, {'confirmation': 'CLEAR'});
    expect(count, 4);
  });

  test('guest deletion follows the planned guest contract', () async {
    final adapter = _JsonAdapter({
      'data': <String, Object?>{},
      'meta': {'requestId': 'request-id'},
    });
    final api = ApiClient(store, dio: Dio()..httpClientAdapter = adapter);

    await api.deleteGuestAccount();

    expect(adapter.request?.path, 'https://example.test/api/v1/guest-account');
    expect(adapter.request?.method, 'DELETE');
    expect(adapter.request?.headers['Authorization'], 'Bearer account-token');
    expect(adapter.request?.headers['Idempotency-Key'], isNotEmpty);
    expect(adapter.request?.data, {'confirmation': 'DELETE'});
  });

  test(
    'notification capture provisioning follows the backend contract',
    () async {
      final adapter = _JsonAdapter({
        'deviceId': '44368a3b-3ab6-4b11-af63-6c37d735a14e',
        'captureCredential': 'bcap_secret',
        'enabledAt': '2026-08-24T10:15:30Z',
      });
      final api = ApiClient(store, dio: Dio()..httpClientAdapter = adapter);

      final provision = await api.provisionNotificationCaptureDevice(
        deviceId: '44368a3b-3ab6-4b11-af63-6c37d735a14e',
      );

      expect(
        adapter.request?.path,
        'https://example.test/api/v1/me/notification-capture-devices',
      );
      expect(adapter.request?.method, 'POST');
      expect(adapter.request?.headers['Authorization'], 'Bearer account-token');
      expect(adapter.request?.data, {
        'deviceId': '44368a3b-3ab6-4b11-af63-6c37d735a14e',
        'platform': 'android',
        'deviceName': 'Android device',
        'appVersion': '1.0.0',
      });
      expect(provision.captureCredential, 'bcap_secret');
    },
  );

  test(
    'notification capture revocation targets the provisioned device',
    () async {
      final adapter = _JsonAdapter(<String, Object?>{});
      final api = ApiClient(store, dio: Dio()..httpClientAdapter = adapter);

      await api.revokeNotificationCaptureDevice(
        '44368a3b-3ab6-4b11-af63-6c37d735a14e',
      );

      expect(
        adapter.request?.path,
        'https://example.test/api/v1/me/notification-capture-devices/44368a3b-3ab6-4b11-af63-6c37d735a14e',
      );
      expect(adapter.request?.method, 'DELETE');
      expect(adapter.request?.headers['Authorization'], 'Bearer account-token');
    },
  );

  test('authenticated 401 preserves local access and pauses sync', () async {
    var unauthorizedNotified = false;
    final adapter = _JsonAdapter({
      'error': {'message': 'Unauthorized'},
    }, statusCode: 401);
    final api = ApiClient(
      store,
      dio: Dio()..httpClientAdapter = adapter,
      onUnauthorized: () => unauthorizedNotified = true,
    );

    await expectLater(api.getProfile(), throwsA(isA<DioException>()));

    final localSession = await store.read();
    expect(localSession, isNotNull);
    expect(localSession?.canAuthenticate, isFalse);
    expect(localSession?.reauthenticationRequired, isTrue);
    expect(unauthorizedNotified, isTrue);
  });

  test('endpoint-specific 401 keeps a session validated by auth me', () async {
    var unauthorizedNotified = false;
    final adapter = _RoutingAdapter((options) {
      if (options.path.endsWith('/auth/me')) {
        return (status: 200, body: <String, Object?>{'username': 'edmund'});
      }
      return (
        status: 401,
        body: <String, Object?>{
          'error': {'message': 'Endpoint unavailable'},
        },
      );
    });
    final api = ApiClient(
      store,
      dio: Dio()..httpClientAdapter = adapter,
      onUnauthorized: () => unauthorizedNotified = true,
    );

    await expectLater(api.getPreferences(), throwsA(isA<DioException>()));

    expect((await store.read())?.token, 'account-token');
    expect(unauthorizedNotified, isFalse);
    expect(adapter.paths, contains('https://example.test/api/v1/auth/me'));
  });

  test('late 401 from an old token cannot erase a newer login', () async {
    final adapter = _DelayedUnauthorizedAdapter();
    final api = ApiClient(store, dio: Dio()..httpClientAdapter = adapter);
    final request = api.getProfile();
    await adapter.requested.future;
    await store.save(
      Session(
        token: 'new-account-token',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        username: 'edmund',
        isGuest: false,
      ),
    );
    adapter.release.complete();

    await expectLater(request, throwsA(isA<DioException>()));

    expect((await store.read())?.token, 'new-account-token');
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.responseData, {this.statusCode = 200});

  final Object responseData;
  final int statusCode;
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
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

typedef _AdapterResponse = ({int status, Map<String, Object?> body});

class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.responseFor);

  final _AdapterResponse Function(RequestOptions options) responseFor;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final response = responseFor(options);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _DelayedUnauthorizedAdapter implements HttpClientAdapter {
  final requested = Completer<void>();
  final release = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.complete();
    await release.future;
    return ResponseBody.fromString(
      jsonEncode({
        'error': {'message': 'Unauthorized'},
      }),
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
