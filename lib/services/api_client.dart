import 'dart:io';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense_summary.dart';
import '../models/session.dart';
import '../models/transaction.dart';
import 'session_store.dart';

class GuestAiTrialLimitException implements Exception {
  const GuestAiTrialLimitException({this.message});
  static const code = 'GUEST_AI_LIMIT_REACHED';
  final String? message;
}

class ApiClient {
  ApiClient(this._sessions, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  static const defaultBaseUrl = 'http://202.10.45.149/api/v1/';
  final SessionStore _sessions;
  final Dio _dio;

  Future<String> get _base async {
    final preferences = await SharedPreferences.getInstance();
    final url = preferences.getString('base_url') ?? defaultBaseUrl;
    return url.endsWith('/') ? url : '$url/';
  }

  Future<Options> _options() async {
    final session = await _sessions.read();
    if (session == null) {
      throw StateError('Session expired. Please sign in again.');
    }
    return Options(headers: {'Authorization': 'Bearer ${session.token}'});
  }

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
    final response = await _dio.post('${await _base}auth/guest-login');
    return _sessionFromResponse(response.data as Map<String, dynamic>);
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

  Session _sessionFromResponse(
    Map<String, dynamic> json, {
    String? fallbackUsername,
  }) {
    final user = json['user'] as Map<String, dynamic>?;
    return Session(
      token: json['token'] as String,
      expiresAt: DateTime.now().add(
        Duration(seconds: (json['expiresIn'] as num).toInt()),
      ),
      username: json['username'] as String? ?? fallbackUsername ?? 'guest',
      isGuest: json['isGuest'] as bool? ?? false,
      remainingAiTrials: (json['remaining_ai_trials'] as num?)?.toInt() ?? 0,
      fullName: user?['fullName'] as String?,
      email: user?['email'] as String?,
    );
  }

  void _throwIfGuestLimit(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['code'] == GuestAiTrialLimitException.code) {
      throw GuestAiTrialLimitException(message: data['message'] as String?);
    }
  }
}
