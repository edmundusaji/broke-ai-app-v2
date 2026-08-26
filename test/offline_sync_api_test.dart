import 'dart:convert';

import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/models/transaction.dart';
import 'package:broke_ai_app/models/transaction_sync.dart';
import 'package:broke_ai_app/services/api_client.dart';
import 'package:broke_ai_app/services/session_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'base_url': 'https://example.test/api/v1/',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'guest bootstrap sends installation identity and preserves local scope',
    () async {
      final store = SessionStore();
      final localGuest = await store.createOfflineGuest();
      final adapter = _ContractAdapter((request) {
        expect(request.path, 'https://example.test/api/v1/auth/guest-login');
        expect(request.method, 'POST');
        expect(request.data['clientGuestId'], localGuest.clientGuestId);
        expect(
          request.data['installationCredential'],
          localGuest.installationCredential,
        );
        return {
          'accountId': 'a7e1bcbf-a682-4d85-b1af-99e996f602fb',
          'token': 'guest-server-token',
          'expiresIn': 3600,
          'username': 'guest_server',
          'isGuest': true,
          'refresh_available': false,
          'remaining_ai_trials': 2,
          'user': {'fullName': 'Guest User', 'email': null},
        };
      });
      final api = ApiClient(store, dio: Dio()..httpClientAdapter = adapter);

      final bootstrapped = await api.guestLogin();

      expect(bootstrapped.token, 'guest-server-token');
      expect(bootstrapped.accountId, isNotNull);
      expect(bootstrapped.accountScope, localGuest.accountScope);
      expect(bootstrapped.clientGuestId, localGuest.clientGuestId);
    },
  );

  test('sync push uses the backend operation and revision contract', () async {
    final store = SessionStore();
    await store.save(_accountSession());
    final adapter = _ContractAdapter((request) {
      expect(request.path, 'https://example.test/api/v1/sync/push');
      expect(request.headers['Authorization'], 'Bearer account-token');
      final body = request.data as Map<String, dynamic>;
      expect(body['deviceId'], 'c23ea049-2a11-45ee-bf36-bf16a08c2de2');
      final operation = (body['operations'] as List).single as Map;
      expect(operation['type'], 'UPDATE');
      expect(operation['baseRevision'], 3);
      expect(operation['clientTransactionId'], isNotEmpty);
      return {
        'results': [
          {
            'operationId': operation['operationId'],
            'status': 'APPLIED',
            'transaction': {
              'id': 4,
              'clientTransactionId': operation['clientTransactionId'],
              'date': '2026-08-25T10:00:00',
              'amount': 30000,
              'category': 'Food',
              'paymentMethod': 'Cash',
              'description': 'Lunch',
              'revision': 4,
            },
          },
        ],
        'serverRevision': 19,
      };
    });
    final api = ApiClient(store, dio: Dio()..httpClientAdapter = adapter);
    const clientId = '93f727de-3da0-461a-8107-ecbb4e49d28b';

    final response = await api.pushTransactions(
      deviceId: 'c23ea049-2a11-45ee-bf36-bf16a08c2de2',
      operations: [
        const TransactionMutation(
          operationId: 'bf2b5ba2-bf03-4991-b045-a98cf3d4428e',
          type: TransactionMutationType.update,
          clientTransactionId: clientId,
          baseRevision: 3,
          transaction: Transaction(
            clientTransactionId: clientId,
            date: '2026-08-25T10:00:00',
            amount: 30000,
            category: 'Food',
            paymentMethod: 'Cash',
            description: 'Lunch',
          ),
        ),
      ],
    );

    expect(response.serverRevision, 19);
    expect(response.results.single.transaction?.revision, 4);
  });

  test('sync pull sends the opaque cursor', () async {
    final store = SessionStore();
    await store.save(_accountSession());
    final adapter = _ContractAdapter((request) {
      expect(request.path, 'https://example.test/api/v1/sync/pull');
      expect(request.queryParameters['cursor'], 'djE6MTg');
      expect(request.queryParameters['limit'], 100);
      return {
        'changes': <Object>[],
        'nextCursor': 'djE6MTk',
        'hasMore': false,
        'serverRevision': 19,
      };
    });
    final api = ApiClient(store, dio: Dio()..httpClientAdapter = adapter);

    final response = await api.pullTransactions(cursor: 'djE6MTg');

    expect(response.nextCursor, 'djE6MTk');
  });
}

Session _accountSession() => Session(
  token: 'account-token',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  username: 'edmund',
  isGuest: false,
  accountId: '0fa58639-bc85-4f1f-b623-d3bd9065565d',
);

class _ContractAdapter implements HttpClientAdapter {
  _ContractAdapter(this.handler);

  final Map<String, dynamic> Function(RequestOptions request) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(handler(options)),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
