import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'payment_method_picker.dart';

const _ink = Color(0xff111111);
const _charcoal = Color(0xff1d1c19);
const _panel = Color(0xff292720);
const _cream = Color(0xfffff7e8);
const _gold = Color(0xffe3b341);
const _goldDark = Color(0xffa36d10);
const _muted = Color(0xffaaa69c);
const _sage = Color(0xff8faa84);
const _coral = Color(0xffd9785d);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  runApp(const ProviderScope(child: BrokeAiApp()));
}

class Transaction {
  const Transaction({
    this.id,
    this.tanggal,
    this.jumlah,
    this.kategori,
    this.merchant,
    this.tipeInput,
  });
  final int? id;
  final String? tanggal, kategori, merchant, tipeInput;
  final double? jumlah;
  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
    id: j['id'] as int?,
    tanggal: j['tanggal'] as String?,
    jumlah: (j['jumlah'] as num?)?.toDouble(),
    kategori: j['kategori'] as String?,
    merchant: j['merchant'] as String?,
    tipeInput: j['tipeInput'] as String?,
  );
}

class CategorySummary {
  const CategorySummary(this.name, this.total);
  final String name;
  final double total;
  factory CategorySummary.fromJson(Map<String, dynamic> j) => CategorySummary(
    j['kategori'] as String? ?? 'Lainnya',
    (j['totalAmount'] as num?)?.toDouble() ?? 0,
  );
}

class ExpenseSummary {
  const ExpenseSummary(this.total, this.categories);
  final double total;
  final List<CategorySummary> categories;
  factory ExpenseSummary.fromJson(Map<String, dynamic> j) => ExpenseSummary(
    (j['totalExpense'] as num?)?.toDouble() ?? 0,
    ((j['categoryBreakdown'] as List?) ?? [])
        .map((e) => CategorySummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class Session {
  const Session({
    required this.token,
    required this.expiresAt,
    required this.username,
    required this.isGuest,
    this.remainingAiTrials = 0,
    this.name,
    this.email,
  });
  final String token, username;
  final DateTime expiresAt;
  final bool isGuest;
  final int remainingAiTrials;
  final String? name, email;
  bool get valid =>
      token.trim().isNotEmpty && expiresAt.isAfter(DateTime.now());
  String get displayName => (name?.isNotEmpty ?? false) ? name! : username;
  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.length > 1
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : parts.first
              .substring(0, parts.first.length.clamp(0, 2))
              .toUpperCase();
  }
}

class SessionStore {
  static const _key = 'session';
  final _storage = const FlutterSecureStorage();
  Session? _activeGuestSession;

  Future<Session?> read() async {
    final guestSession = _activeGuestSession;
    if (guestSession != null) {
      if (guestSession.valid) return guestSession;
      _activeGuestSession = null;
    }

    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final session = Session(
        token: j['token'] as String,
        username: j['username'] as String,
        isGuest: j['isGuest'] as bool? ?? false,
        remainingAiTrials: (j['remaining_ai_trials'] as num?)?.toInt() ?? 0,
        name: j['name'] as String?,
        email: j['email'] as String?,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
      );
      // Guest access must always begin with an explicit Try Now action.
      // Discard legacy persisted guest sessions from older app versions.
      if (!session.isGuest && session.valid) return session;
    } catch (_) {
      // Malformed or legacy session data must never block the entry screen.
    }
    try {
      await clear();
    } catch (_) {
      // Continue as signed out even if secure storage cannot be cleaned up.
    }
    return null;
  }

  Future<void> save(Session session) async {
    if (session.isGuest) {
      _activeGuestSession = session;
      // Do not restore a guest account after an app restart or reinstall.
      try {
        await _storage.delete(key: _key);
      } catch (_) {
        // The in-memory guest session remains usable for this app process.
      }
      return;
    }

    _activeGuestSession = null;
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'token': session.token,
        'username': session.username,
        'isGuest': false,
        'remaining_ai_trials': session.remainingAiTrials,
        'name': session.name,
        'email': session.email,
        'expiresAt': session.expiresAt.toIso8601String(),
      }),
    );
  }

  Future<void> clear() async {
    _activeGuestSession = null;
    await _storage.delete(key: _key);
  }

  void updateActiveGuestTrials(int remainingTrials) {
    final session = _activeGuestSession;
    if (session == null || !session.isGuest) return;
    _activeGuestSession = Session(
      token: session.token,
      expiresAt: session.expiresAt,
      username: session.username,
      isGuest: true,
      remainingAiTrials: remainingTrials.clamp(0, 2),
      name: session.name,
      email: session.email,
    );
  }
}

class ApiClient {
  ApiClient(this._sessions)
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
  final SessionStore _sessions;
  final Dio _dio;
  static const defaultBaseUrl = 'http://202.10.45.149/api/v1/';
  Future<String> get _base async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString('base_url') ?? defaultBaseUrl;
    return url.endsWith('/') ? url : '$url/';
  }

  Future<Options> _options() async {
    final s = await _sessions.read();
    if (s == null) throw StateError('Sesi berakhir. Silakan masuk kembali.');
    return Options(headers: {'Authorization': 'Bearer ${s.token}'});
  }

  Future<Session> login(String username, String password) async {
    final r = await _dio.post(
      '${await _base}auth/login',
      data: {'username': username.trim(), 'password': password},
    );
    return _sessionFromResponse(
      r.data as Map<String, dynamic>,
      fallbackUsername: username.trim(),
    );
  }

  Future<Session> guestLogin() async {
    final r = await _dio.post('${await _base}auth/guest-login');
    return _sessionFromResponse(r.data as Map<String, dynamic>);
  }

  Session _sessionFromResponse(
    Map<String, dynamic> json, {
    String? fallbackUsername,
  }) {
    final user = json['user'] as Map<String, dynamic>?;
    return Session(
      token: json['token'] as String,
      username: json['username'] as String? ?? fallbackUsername ?? 'guest',
      isGuest: json['isGuest'] as bool? ?? false,
      remainingAiTrials: (json['remaining_ai_trials'] as num?)?.toInt() ?? 0,
      name: user?['name'] as String?,
      email: user?['email'] as String?,
      expiresAt: DateTime.now().add(
        Duration(seconds: (json['expiresIn'] as num).toInt()),
      ),
    );
  }

  Future<void> register(
    String name,
    String username,
    String email,
    String password,
  ) async => _dio.post(
    '${await _base}auth/register',
    data: {
      'namaLengkap': name.trim(),
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
    },
  );
  Future<ExpenseSummary> summary(DateTime d) async {
    final r = await _dio.get(
      '${await _base}expense/summary',
      queryParameters: {'month': d.month, 'year': d.year},
      options: await _options(),
    );
    return ExpenseSummary.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<Transaction>> history(DateTime d) async {
    final r = await _dio.get(
      '${await _base}expense/history',
      queryParameters: {'month': d.month, 'year': d.year},
      options: await _options(),
    );
    return (r.data as List)
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Transaction> notification(String text) async {
    try {
      final r = await _dio.post(
        '${await _base}expense/notification',
        data: {'text': text.trim()},
        options: await _options(),
      );
      return Transaction.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (error) {
      _throwIfGuestAiLimit(error);
      rethrow;
    }
  }

  Future<Transaction> receipt(File file) async {
    try {
      final r = await _dio.post(
        '${await _base}expense/receipt',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path),
        }),
        options: await _options(),
      );
      return Transaction.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (error) {
      _throwIfGuestAiLimit(error);
      rethrow;
    }
  }

  Future<int> remainingAiTrials() async {
    final response = await _dio.get(
      '${await _base}auth/me',
      options: await _options(),
    );
    final json = response.data as Map<String, dynamic>;
    return (json['remaining_ai_trials'] as num?)?.toInt() ?? 0;
  }

  Future<Transaction> createManualTransaction({
    required DateTime date,
    required double amount,
    required String category,
    required String merchant,
  }) async {
    final r = await _dio.post(
      '${await _base}expense/manual',
      data: {
        'date': DateFormat('yyyy-MM-dd').format(date),
        'amount': amount,
        'category': category.trim(),
        // The backend schema still stores the selected payment method here.
        'merchant': merchant.trim(),
      },
      options: await _options(),
    );
    return Transaction.fromJson(r.data as Map<String, dynamic>);
  }

  void _throwIfGuestAiLimit(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['code'] == GuestAiTrialLimitException.code) {
      throw GuestAiTrialLimitException(message: data['message'] as String?);
    }
  }
}

class GuestAiTrialLimitException implements Exception {
  const GuestAiTrialLimitException({this.message});

  static const code = 'GUEST_AI_LIMIT_REACHED';
  final String? message;
}

final sessionStoreProvider = Provider((_) => SessionStore());
final apiProvider = Provider(
  (ref) => ApiClient(ref.watch(sessionStoreProvider)),
);
final sessionProvider = FutureProvider<Session?>(
  (ref) => ref.watch(sessionStoreProvider).read(),
);
final showAuthProvider = StateProvider<bool>((_) => false);
final remainingAiTrialsProvider = StateProvider<int?>((ref) {
  final session = ref.watch(sessionProvider).value;
  return session?.isGuest == true ? session!.remainingAiTrials : null;
});
final selectedMonthProvider = StateProvider<DateTime>(
  (_) => DateTime(DateTime.now().year, DateTime.now().month),
);
final dashboardProvider =
    FutureProvider.autoDispose<
      ({ExpenseSummary summary, List<Transaction> history})
    >((ref) async {
      final date = ref.watch(selectedMonthProvider);
      final api = ref.watch(apiProvider);
      return (
        summary: await api.summary(date),
        history: await api.history(date),
      );
    });

class BrokeAiApp extends StatelessWidget {
  const BrokeAiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Broke.AI',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _gold,
        brightness: Brightness.dark,
      ),
      fontFamily: 'sans',
    ),
    home: const AuthGate(),
  );
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});
  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  Widget build(BuildContext context) {
    final showAuth = ref.watch(showAuthProvider);
    return ref
        .watch(sessionProvider)
        .when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator(color: _gold)),
          ),
          error: (_, _) => const AccountOptionScreen(
            startupError: 'Unable to restore your session. Please try again.',
          ),
          data: (session) => session != null
              ? const Shell()
              : showAuth
              ? AuthScreen(
                  onBack: () =>
                      ref.read(showAuthProvider.notifier).state = false,
                )
              : const AccountOptionScreen(),
        );
  }
}

class WelcomeFlow extends StatefulWidget {
  const WelcomeFlow({super.key, required this.onFinish});
  final VoidCallback onFinish;
  @override
  State<WelcomeFlow> createState() => _WelcomeFlowState();
}

class _WelcomeFlowState extends State<WelcomeFlow> {
  final controller = PageController();
  final Set<int> multiChoices = {0};
  int page = 0, choice = 0;
  final steps = const [
    (
      'Catat dengan caramu',
      'Pilih cara paling nyaman untuk memasukkan pengeluaran.',
      [
        Icons.document_scanner_outlined,
        Icons.notifications_active_outlined,
        Icons.edit_note_outlined,
      ],
      ['Scan struk', 'Dari notifikasi', 'Input manual'],
    ),
    (
      'Apa tujuanmu?',
      'Kami akan menata ringkasan supaya terasa lebih berguna.',
      [
        Icons.pie_chart_outline,
        Icons.savings_outlined,
        Icons.track_changes_outlined,
      ],
      ['Kontrol pengeluaran', 'Bangun tabungan', 'Lihat kebiasaan belanja'],
    ),
    (
      'Broke.AI siap bantu',
      'Setiap bukti belanja diubah menjadi insight yang jelas.',
      [
        Icons.auto_awesome_outlined,
        Icons.receipt_long_outlined,
        Icons.insights_outlined,
      ],
      ['Kategori otomatis', 'Riwayat rapi', 'Ringkasan bulanan'],
    ),
  ];
  void next() {
    if (page == steps.length - 1) {
      widget.onFinish();
    } else {
      controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'BROKE.AI',
                  style: TextStyle(
                    letterSpacing: 1.8,
                    color: _gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text('${page + 1}/3', style: const TextStyle(color: _muted)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 5,
                      margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: i <= page ? _gold : _panel,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: controller,
                onPageChanged: (value) => setState(() {
                  page = value;
                  choice = 0;
                  multiChoices
                    ..clear()
                    ..add(0);
                }),
                itemCount: steps.length,
                itemBuilder: (_, i) {
                  final step = steps[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Center(
                        child: _HeroIcon(icon: step.$3[choice], size: 122),
                      ),
                      const SizedBox(height: 34),
                      Text(
                        step.$1,
                        style: const TextStyle(
                          fontSize: 30,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: _cream,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        step.$2,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...List.generate(
                        step.$4.length,
                        (index) => _SelectCard(
                          label: step.$4[index],
                          icon: step.$3[index],
                          multiple: page == 1,
                          selected: page == 1
                              ? multiChoices.contains(index)
                              : choice == index,
                          onTap: () => setState(() {
                            if (page == 1) {
                              multiChoices.contains(index)
                                  ? multiChoices.remove(index)
                                  : multiChoices.add(index);
                            } else {
                              choice = index;
                            }
                          }),
                        ),
                      ),
                      const Spacer(),
                    ],
                  );
                },
              ),
            ),
            Row(
              children: [
                if (page > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: page == 0
                          ? null
                          : () => controller.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _cream,
                        side: const BorderSide(color: Color(0xff58544b)),
                        minimumSize: const Size(0, 54),
                      ),
                      child: const Text('<  Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: next,
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _ink,
                      minimumSize: const Size(0, 54),
                    ),
                    child: Text(page == 2 ? 'Get started  >' : 'Continue  >'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class AccountOptionScreen extends ConsumerStatefulWidget {
  const AccountOptionScreen({super.key, this.startupError});

  final String? startupError;

  @override
  ConsumerState<AccountOptionScreen> createState() =>
      _AccountOptionScreenState();
}

class _AccountOptionScreenState extends ConsumerState<AccountOptionScreen> {
  bool loading = false;
  String? error;

  Future<void> _tryNow() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final session = await ref.read(apiProvider).guestLogin();
      await ref.read(sessionStoreProvider).save(session);
      ref.read(showAuthProvider.notifier).state = false;
      ref.invalidate(sessionProvider);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Unable to start Guest Mode. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: 28),
                  const Text(
                    'How would you like to start?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Explore manual expense tracking instantly, or sign in to unlock every AI feature.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, height: 1.45),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xff3d3930)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.rocket_launch_outlined, color: _gold),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Guest Mode includes the dashboard, history, and manual transactions.',
                            style: TextStyle(color: _cream, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((error ?? widget.startupError) != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      (error ?? widget.startupError)!,
                      style: const TextStyle(color: _coral),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: loading ? null : _tryNow,
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _ink,
                      minimumSize: const Size(0, 54),
                    ),
                    child: Text(
                      loading ? 'Starting Guest Mode...' : 'Try Now  >',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: loading
                        ? null
                        : () =>
                              ref.read(showAuthProvider.notifier).state = true,
                    style: _secondaryButton(),
                    child: const Text('Sign In / Register'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.error, this.onBack});
  final String? error;
  final VoidCallback? onBack;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final controllers = List.generate(5, (_) => TextEditingController());
  bool register = false, loading = false;
  String? error;
  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = ref.read(apiProvider);
      if (register) {
        if (controllers[3].text != controllers[4].text) {
          throw Exception('Konfirmasi kata sandi tidak cocok.');
        }
        await api.register(
          controllers[0].text,
          controllers[1].text,
          controllers[2].text,
          controllers[3].text,
        );
        setState(() => register = false);
      } else {
        final s = await api.login(controllers[0].text, controllers[1].text);
        await ref.read(sessionStoreProvider).save(s);
        ref.invalidate(sessionProvider);
      }
    } catch (e) {
      setState(
        () => error = e is DioException
            ? 'Tidak dapat tersambung ke server.'
            : e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = register
        ? [
            'Nama lengkap',
            'Username',
            'Email',
            'Kata sandi',
            'Konfirmasi kata sandi',
          ]
        : ['Username', 'Kata sandi'];
    final message = error ?? widget.error;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.onBack != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Back to start options',
                          onPressed: loading ? null : widget.onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                    const _BrandMark(),
                    const SizedBox(height: 28),
                    Text(
                      register ? 'Mulai kebiasaan baru.' : 'Welcome back.',
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Satu tempat untuk tiap cerita pengeluaran.',
                      style: TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 22),
                    ...List.generate(
                      labels.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: controllers[i],
                          obscureText: labels[i].contains('sandi'),
                          decoration: _input(labels[i]),
                        ),
                      ),
                    ),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          message,
                          style: const TextStyle(color: _coral),
                        ),
                      ),
                    FilledButton(
                      onPressed: loading ? null : submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _ink,
                        minimumSize: const Size(0, 54),
                      ),
                      child: Text(
                        loading
                            ? 'Memproses...'
                            : register
                            ? 'Buat akun  >'
                            : 'Masuk  >',
                      ),
                    ),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => setState(() {
                              register = !register;
                              error = null;
                            }),
                      child: Text(
                        register
                            ? 'Sudah punya akun? Masuk'
                            : 'Belum punya akun? Daftar',
                        style: const TextStyle(color: _cream),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});
  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      const Dashboard(),
      const CaptureScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: pages[page],
      floatingActionButton: page == 0
          ? FloatingActionButton(
              tooltip: 'Add manual transaction',
              backgroundColor: _gold,
              foregroundColor: _ink,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ManualTransactionSheet(),
              ),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _charcoal,
          border: Border(top: BorderSide(color: Color(0xff37342d))),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xff51401b),
          selectedIndex: page,
          onDestinationSelected: (i) => setState(() => page = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.document_scanner_outlined),
              label: 'Scan',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class Dashboard extends ConsumerWidget {
  const Dashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedMonthProvider);
    final data = ref.watch(dashboardProvider);
    final user = ref.watch(sessionProvider).value;
    return SafeArea(
      child: data.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _gold)),
        error: (e, _) => _DashboardError(error: e.toString()),
        data: (d) => RefreshIndicator(
          color: _gold,
          onRefresh: () => ref.refresh(dashboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${user?.displayName.split(' ').first ?? 'There'}',
                          style: const TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Mari cek kondisi dompetmu.',
                          style: TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  _RoundButton(
                    icon: Icons.notifications_none_rounded,
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SurfaceCard(
                tint: _goldDark,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pengeluaran bulan ini',
                            style: TextStyle(color: _cream),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _money(d.summary.total),
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _Badge(
                            label: 'Tersinkronisasi',
                            icon: Icons.check_circle_outline,
                          ),
                        ],
                      ),
                    ),
                    const _HeroIcon(
                      icon: Icons.account_balance_wallet_rounded,
                      size: 78,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _MetricCard(
                    label: 'Hari ini',
                    value: _money(
                      d.history
                          .where((x) => _isToday(x.tanggal))
                          .fold<double>(0, (v, x) => v + (x.jumlah ?? 0)),
                    ),
                    icon: Icons.today_outlined,
                    color: _sage,
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    label: 'Transaksi',
                    value: '${d.history.length}',
                    icon: Icons.receipt_long_outlined,
                    color: _coral,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Text(
                    'Spending overview',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  _MonthPicker(date: date),
                ],
              ),
              const SizedBox(height: 10),
              SurfaceCard(
                child: d.summary.categories.isEmpty
                    ? const SizedBox(
                        height: 200,
                        child: Center(
                          child: Text(
                            'Belum ada transaksi.\nYuk, scan struk pertama.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 160,
                            child: PieChart(
                              PieChartData(
                                centerSpaceRadius: 43,
                                sectionsSpace: 3,
                                sections: d.summary.categories
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => PieChartSectionData(
                                        value: e.value.total,
                                        color: _categoryColor(e.value.name),
                                        radius: 44,
                                        title: '',
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 7,
                            children: d.summary.categories
                                .map(
                                  (c) => _Legend(
                                    color: _categoryColor(c.name),
                                    icon: _categoryIcon(c.name),
                                    label:
                                        '${c.name} (${(c.total / d.summary.total * 100).round()}%)',
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Aktivitas terbaru',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: d.history.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Riwayat akan tampil di sini.',
                          style: TextStyle(color: _muted),
                        ),
                      )
                    : Column(
                        children: d.history
                            .take(5)
                            .map((x) => _TransactionTile(transaction: x))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _manualTransactionCategories = <String>[
  'Food',
  'Transport',
  'Lifestyle',
  'Health',
  'Donation',
  'Utility',
  'Payment',
];

String? _canonicalManualCategory(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  if (normalized.isEmpty) return null;
  for (final category in _manualTransactionCategories) {
    if (category.toLowerCase() == normalized) return category;
  }
  if (normalized.contains('makan') || normalized.contains('culinary')) {
    return 'Food';
  }
  if (normalized.contains('gojek') ||
      normalized.contains('grab') ||
      normalized.contains('motor')) {
    return 'Transport';
  }
  if (normalized.contains('belanja') || normalized.contains('shop')) {
    return 'Lifestyle';
  }
  if (normalized.contains('sehat') || normalized.contains('kesehatan')) {
    return 'Health';
  }
  if (normalized.contains('donasi')) return 'Donation';
  if (normalized.contains('tagihan') ||
      normalized.contains('listrik') ||
      normalized.contains('water')) {
    return 'Utility';
  }
  if (normalized.contains('bayar') ||
      normalized.contains('transfer') ||
      normalized.contains('bank')) {
    return 'Payment';
  }
  return null;
}

class ManualTransactionSheet extends ConsumerStatefulWidget {
  const ManualTransactionSheet({super.key, this.transaction});

  final Transaction? transaction;

  @override
  ConsumerState<ManualTransactionSheet> createState() =>
      _ManualTransactionSheetState();
}

class _ManualTransactionSheetState
    extends ConsumerState<ManualTransactionSheet> {
  late final TextEditingController amount;
  late DateTime date;
  String? category;
  String? paymentMethod;
  bool saving = false;
  bool showValidation = false;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    amount = TextEditingController(text: transaction?.jumlah?.toString() ?? '');
    category = _canonicalManualCategory(transaction?.kategori);
    paymentMethod = transaction?.merchant?.trim().isEmpty == false
        ? transaction!.merchant!.trim()
        : null;
    date = DateTime.tryParse(transaction?.tanggal ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> _selectPaymentMethod() async {
    final selected = await showPaymentMethodPicker(
      context,
      selectedValue: paymentMethod,
    );
    if (selected != null && mounted) {
      setState(() {
        paymentMethod = selected;
        showValidation = false;
      });
    }
  }

  Future<void> submit() async {
    final parsedAmount = double.tryParse(amount.text.replaceAll(',', '.'));
    if (parsedAmount == null ||
        parsedAmount <= 0 ||
        category == null ||
        paymentMethod == null) {
      setState(() => showValidation = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the amount, category, and payment method.'),
        ),
      );
      return;
    }

    setState(() => saving = true);
    try {
      await ref
          .read(apiProvider)
          .createManualTransaction(
            date: date,
            amount: parsedAmount,
            category: category!,
            // Payment remains mapped to merchant for backend DTO compatibility.
            merchant: paymentMethod!,
          );
      ref.invalidate(dashboardProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save transaction.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      12,
      12,
      12,
      MediaQuery.viewInsetsOf(context).bottom + 12,
    ),
    child: SurfaceCard(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Manual transaction',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDate: date,
                );
                if (picked != null) setState(() => date = picked);
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(DateFormat.yMMMMd('id_ID').format(date)),
              style: _secondaryButton(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => showValidation = false),
              decoration: _input('Amount').copyWith(
                prefixText: 'Rp ',
                errorText:
                    showValidation &&
                        (double.tryParse(amount.text.replaceAll(',', '.')) ??
                                0) <=
                            0
                    ? 'Enter a valid amount'
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              dropdownColor: _panel,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _gold),
              decoration: _input('Category').copyWith(
                errorText: showValidation && category == null
                    ? 'Select a category'
                    : null,
              ),
              items: _manualTransactionCategories
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Row(
                        children: [
                          Icon(
                            _categoryIcon(option),
                            size: 19,
                            color: _categoryColor(option),
                          ),
                          const SizedBox(width: 10),
                          Text(option),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                category = value;
                showValidation = false;
              }),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _selectPaymentMethod,
              borderRadius: BorderRadius.circular(15),
              child: InputDecorator(
                isEmpty: paymentMethod == null,
                decoration: _input('').copyWith(
                  errorText: showValidation && paymentMethod == null
                      ? 'Select a payment method'
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      paymentMethod == null
                          ? Icons.account_balance_wallet_outlined
                          : Icons.account_balance_wallet_rounded,
                      color: paymentMethod == null ? _muted : _gold,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        paymentMethod ?? 'Choose payment method',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: paymentMethod == null ? _muted : _cream,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _gold),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: saving ? null : submit,
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _ink,
                minimumSize: const Size(0, 52),
              ),
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _ink,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(saving ? 'Saving...' : 'Add transaction'),
            ),
          ],
        ),
      ),
    ),
  );
}

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});
  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  XFile? image;
  bool busy = false;
  final manual = TextEditingController();
  @override
  void dispose() {
    manual.dispose();
    super.dispose();
  }

  Future<void> pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked != null) setState(() => image = picked);
  }

  Future<void> send() async {
    if (image == null) return;
    if (await _blockIfGuestTrialsExhausted()) return;
    setState(() => busy = true);
    try {
      final result = await ref.read(apiProvider).receipt(File(image!.path));
      await _consumeAndRefreshGuestTrial();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tercatat: ${_money(result.jumlah ?? 0)}')),
        );
        setState(() => image = null);
        ref.invalidate(dashboardProvider);
      }
    } on GuestAiTrialLimitException {
      if (mounted) {
        _setRemainingGuestTrials(0);
        await _showGuestAiLimit();
      }
    } catch (_) {
      await _queue('receipt', image!.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disimpan di antrean offline.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> notification() async {
    if (manual.text.trim().isEmpty) return;
    if (await _blockIfGuestTrialsExhausted()) return;
    try {
      await ref.read(apiProvider).notification(manual.text);
      await _consumeAndRefreshGuestTrial();
      manual.clear();
      ref.invalidate(dashboardProvider);
    } on GuestAiTrialLimitException {
      if (mounted) {
        _setRemainingGuestTrials(0);
        await _showGuestAiLimit();
      }
    } catch (_) {
      await _queue('notification', manual.text);
    }
  }

  Future<bool> _blockIfGuestTrialsExhausted() async {
    final session = ref.read(sessionProvider).value;
    final remaining = ref.read(remainingAiTrialsProvider);
    if (session?.isGuest == true && remaining == 0) {
      await _showGuestAiLimit();
      return true;
    }
    return false;
  }

  Future<void> _consumeAndRefreshGuestTrial() async {
    if (ref.read(sessionProvider).value?.isGuest != true) return;

    final current = ref.read(remainingAiTrialsProvider);
    if (current != null) {
      _setRemainingGuestTrials(current - 1);
    }

    try {
      final authoritativeCount = await ref
          .read(apiProvider)
          .remainingAiTrials();
      if (mounted) {
        _setRemainingGuestTrials(authoritativeCount);
      }
    } catch (_) {
      // Keep the optimistic local count until the next successful refresh.
    }
  }

  void _setRemainingGuestTrials(int remainingTrials) {
    final boundedCount = remainingTrials.clamp(0, 2);
    ref.read(remainingAiTrialsProvider.notifier).state = boundedCount;
    ref.read(sessionStoreProvider).updateActiveGuestTrials(boundedCount);
  }

  Future<void> _showGuestAiLimit() async {
    final action = await showModalBottomSheet<_GuestAiLimitAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GuestAiLimitSheet(),
    );
    if (!mounted || action == null) return;

    if (action == _GuestAiLimitAction.authenticate) {
      try {
        await ref.read(sessionStoreProvider).clear();
      } finally {
        ref.read(showAuthProvider.notifier).state = true;
        ref.invalidate(sessionProvider);
      }
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ManualTransactionSheet(),
    );
  }

  Future<void> _queue(String type, String payload) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('offline_queue') ?? [];
    list.add(
      jsonEncode({
        'type': type,
        'payload': payload,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );
    await p.setStringList('offline_queue', list);
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(sessionProvider).value?.isGuest == true;
    final remainingTrials = ref.watch(remainingAiTrialsProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Scan a receipt',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              _RoundButton(
                icon: Icons.close_rounded,
                onTap: () => setState(() => image = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Posisikan seluruh struk di dalam area fokus.',
            style: TextStyle(color: _muted),
          ),
          if (isGuest) ...[
            const SizedBox(height: 12),
            _AiTrialBadge(remaining: remainingTrials ?? 0),
          ],
          const SizedBox(height: 22),
          _ScanViewport(image: image, loading: busy),
          const SizedBox(height: 16),
          if (busy)
            const _AiStatus()
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                    style: _secondaryButton(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_outlined),
                    label: const Text('Gallery'),
                    style: _secondaryButton(),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: image == null || busy ? null : send,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _ink,
              minimumSize: const Size(0, 54),
            ),
            child: Text(busy ? 'Analyzing with AI...' : 'Analyze receipt  >'),
          ),
          const SizedBox(height: 28),
          const Text(
            'Input Teks Notifikasi / Manual',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: manual,
            maxLines: 3,
            decoration: _input(
              'Paste notification or transaction text here...',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: notification,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _ink,
              minimumSize: const Size(0, 52),
            ),
            child: const Text('Proses Transaksi >'),
          ),
        ],
      ),
    );
  }
}

enum _GuestAiLimitAction { authenticate, manual }

class _AiTrialBadge extends StatelessWidget {
  const _AiTrialBadge({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final count = remaining.clamp(0, 2);
    final exhausted = count == 0;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: exhausted ? const Color(0xff3b211f) : const Color(0xff493b1b),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: exhausted ? _coral : _gold),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              exhausted ? Icons.lock_outline_rounded : Icons.auto_awesome,
              color: exhausted ? _coral : _gold,
              size: 17,
            ),
            const SizedBox(width: 7),
            Text(
              exhausted
                  ? 'No Free Scans Left'
                  : '$count Free Scan${count == 1 ? '' : 's'} Left',
              style: TextStyle(
                color: exhausted ? _coral : _cream,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestAiLimitSheet extends StatelessWidget {
  const _GuestAiLimitSheet();

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      12,
      12,
      12,
      MediaQuery.viewInsetsOf(context).bottom + 12,
    ),
    child: SurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Cancel',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          const _HeroIcon(icon: Icons.rocket_launch_rounded, size: 82),
          const SizedBox(height: 18),
          const Text(
            'Unlock Unlimited AI Scans!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          const Text(
            "You've used your 2 free guest trials. Create a free account or sign in to keep scanning receipts automatically.",
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, height: 1.45),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, _GuestAiLimitAction.authenticate),
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _ink,
              minimumSize: const Size(0, 54),
            ),
            icon: const Icon(Icons.login_rounded),
            label: const Text('Sign In / Register'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, _GuestAiLimitAction.manual),
            style: _secondaryButton(),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Use Manual Input'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
        ],
      ),
    ),
  );
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider).value;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          const Text(
            'Profile & settings',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          SurfaceCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 39,
                  backgroundColor: _gold,
                  child: Text(
                    s?.initials ?? 'BA',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  s?.displayName ?? 'There',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  s?.email ?? 'email belum tersedia',
                  style: const TextStyle(color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            tint: _goldDark,
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Make every rupiah count',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Scan receipts for a cleaner financial story.',
                        style: TextStyle(color: _cream),
                      ),
                    ],
                  ),
                ),
                _HeroIcon(icon: Icons.auto_awesome_rounded, size: 66),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Account',
            style: TextStyle(color: _cream, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Manage profile',
                ),
                _SettingTile(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                ),
                _SettingTile(
                  icon: Icons.language_rounded,
                  label: 'Server settings',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Support',
            style: TextStyle(color: _cream, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & FAQ',
                ),
                _SettingTile(
                  icon: Icons.bug_report_outlined,
                  label: 'Report a bug',
                ),
                _SettingTile(
                  icon: Icons.logout_rounded,
                  label: 'Log out',
                  danger: true,
                  onTap: () async {
                    ref.read(showAuthProvider.notifier).state = false;
                    await ref.read(sessionStoreProvider).clear();
                    ref.invalidate(sessionProvider);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.tint,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? tint;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: tint ?? _charcoal,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: (tint ?? _charcoal).withValues(alpha: .8)),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8)),
      ],
    ),
    child: child,
  );
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon, required this.size});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _goldDark,
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 10,
              offset: Offset(0, 7),
            ),
          ],
        ),
      ),
      Transform.translate(
        offset: const Offset(-8, -7),
        child: Container(
          width: size * .76,
          height: size * .76,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _gold),
          child: Icon(icon, color: _ink, size: size * .40),
        ),
      ),
    ],
  );
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.multiple,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final bool multiple;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff3a311d) : const Color(0xff242424),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _gold : const Color(0xff333333),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? _gold : _panel,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: selected ? _ink : _cream),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: multiple ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: multiple ? BorderRadius.circular(7) : null,
                color: selected ? _gold : Colors.transparent,
                border: Border.all(color: selected ? _gold : _muted),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 15, color: _ink)
                  : null,
            ),
          ],
        ),
      ),
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        const _HeroIcon(icon: Icons.account_balance_wallet_rounded, size: 76),
        const SizedBox(height: 12),
        Text(
          'BROKE.AI',
          style: TextStyle(
            letterSpacing: 2.2,
            color: _gold,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: _charcoal,
    shape: const CircleBorder(),
    child: IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: _cream),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: _ink, size: 19),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      ),
    ),
  );
}

class _MonthPicker extends ConsumerWidget {
  const _MonthPicker({required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      GestureDetector(
        onTap: () => ref.read(selectedMonthProvider.notifier).state = DateTime(
          date.year,
          date.month - 1,
        ),
        child: const Icon(Icons.chevron_left, color: _gold),
      ),
      Text(
        DateFormat('MMM y', 'id_ID').format(date),
        style: const TextStyle(color: _gold, fontWeight: FontWeight.w700),
      ),
      GestureDetector(
        onTap: () => ref.read(selectedMonthProvider.notifier).state = DateTime(
          date.year,
          date.month + 1,
        ),
        child: const Icon(Icons.chevron_right, color: _gold),
      ),
    ],
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.icon, required this.label});
  final Color color;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: _ink.withValues(alpha: .3),
      borderRadius: BorderRadius.circular(50),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _cream),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: _cream)),
      ],
    ),
  );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});
  final Transaction transaction;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _categoryColor(transaction.kategori ?? ''),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(_categoryIcon(transaction.kategori ?? ''), color: _ink),
    ),
    title: Text(
      transaction.kategori ?? 'Lainnya',
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      transaction.merchant ??
          transaction.tipeInput ??
          _shortDate(transaction.tanggal),
      style: const TextStyle(color: _muted),
    ),
    trailing: Text(
      '-${_money(transaction.jumlah ?? 0)}',
      style: TextStyle(
        color: _categoryColor(transaction.kategori ?? ''),
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: SurfaceCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: _gold, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Dashboard belum bisa dimuat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScanViewport extends StatelessWidget {
  const _ScanViewport({required this.image, required this.loading});
  final XFile? image;
  final bool loading;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: .79,
    child: Container(
      decoration: BoxDecoration(
        color: _charcoal,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _goldDark, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              Image.file(File(image!.path), fit: BoxFit.cover)
            else
              const ColoredBox(color: Color(0xff24221d)),
            const CustomPaint(painter: _FocusMaskPainter()),
            Center(
              child: Container(
                width: 225,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: _gold, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: const [
                    Positioned(
                      top: -5,
                      left: 18,
                      right: 18,
                      child: Divider(color: _gold, thickness: 3),
                    ),
                    Positioned(
                      bottom: -5,
                      left: 18,
                      right: 18,
                      child: Divider(color: _gold, thickness: 3),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 22,
              left: 0,
              right: 0,
              child: Text(
                loading
                    ? 'Analyzing with AI...'
                    : image == null
                    ? 'Ready to scan'
                    : 'Receipt ready',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _cream,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AiStatus extends StatelessWidget {
  const _AiStatus();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _gold),
        ),
        SizedBox(width: 10),
        Text(
          'Analyzing with AI...',
          style: TextStyle(color: _gold, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _FocusMaskPainter extends CustomPainter {
  const _FocusMaskPainter();
  @override
  void paint(Canvas canvas, Size size) {
    const width = 225.0;
    const height = 300.0;
    final cutout = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: width,
        height: height,
      ),
      const Radius.circular(20),
    );
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(cutout);
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: .5));
  }

  @override
  bool shouldRepaint(covariant _FocusMaskPainter oldDelegate) => false;
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: danger ? const Color(0xffff5252).withValues(alpha: .18) : _panel,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        size: 19,
        color: danger ? const Color(0xffff5252) : _gold,
      ),
    ),
    title: Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: danger ? const Color(0xffff5252) : _cream,
      ),
    ),
    trailing: Icon(
      Icons.arrow_forward_rounded,
      color: danger ? const Color(0xffff5252) : _muted,
      size: 18,
    ),
  );
}

InputDecoration _input(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: _muted),
  filled: true,
  fillColor: _panel,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: Color(0xff3d3930)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: _gold, width: 1.5),
  ),
);
ButtonStyle _secondaryButton() => OutlinedButton.styleFrom(
  foregroundColor: _cream,
  side: const BorderSide(color: Color(0xff4c473d)),
  minimumSize: const Size(0, 52),
);
Color _categoryColor(String name) {
  final n = name.toLowerCase();
  if (n.contains('makan') || n.contains('food')) {
    return _coral;
  }
  if (n.contains('transport') ||
      n.contains('gojek') ||
      n.contains('grab') ||
      n.contains('motor')) {
    return _sage;
  }
  if (n.contains('belanja') || n.contains('shop') || n.contains('lifestyle')) {
    return const Color(0xffb497e8);
  }
  if (n.contains('sehat') || n.contains('health') || n.contains('kesehatan')) {
    return const Color(0xff74b6ab);
  }
  if (n.contains('donasi') || n.contains('donation')) {
    return const Color(0xffdf7e97);
  }
  if (n.contains('utility') ||
      n.contains('tagihan') ||
      n.contains('listrik') ||
      n.contains('electricity') ||
      n.contains('water') ||
      n.contains('air')) {
    return const Color(0xffd5a94f);
  }
  if (n.contains('payment') ||
      n.contains('bayar') ||
      n.contains('transfer') ||
      n.contains('bank')) {
    return const Color(0xff76a5cf);
  }
  return _gold;
}

IconData _categoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('makan') || n.contains('food')) {
    return Icons.restaurant;
  }
  if (n.contains('transport') ||
      n.contains('gojek') ||
      n.contains('grab') ||
      n.contains('motor')) {
    return Icons.two_wheeler;
  }
  if (n.contains('sehat') || n.contains('health') || n.contains('kesehatan')) {
    return Icons.medical_services;
  }
  if (n.contains('donasi') || n.contains('donation')) {
    return Icons.volunteer_activism;
  }
  if (n.contains('utility') ||
      n.contains('tagihan') ||
      n.contains('listrik') ||
      n.contains('electricity') ||
      n.contains('water') ||
      n.contains('air')) {
    return Icons.bolt;
  }
  if (n.contains('payment') ||
      n.contains('bayar') ||
      n.contains('transfer') ||
      n.contains('bank')) {
    return Icons.payments;
  }
  if (n.contains('belanja') || n.contains('shop') || n.contains('lifestyle')) {
    return Icons.shopping_bag;
  }
  return Icons.category;
}

String _money(double amount) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
).format(amount);
String _shortDate(String? date) {
  try {
    return DateFormat('d MMM', 'id_ID').format(DateTime.parse(date!));
  } catch (_) {
    return '-';
  }
}

bool _isToday(String? date) {
  try {
    final d = DateTime.parse(date!);
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  } catch (_) {
    return false;
  }
}
