import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../providers/app_providers.dart';
import '../widgets/common_widgets.dart';
import '../widgets/surface_card.dart';

class AccountOptionPage extends ConsumerStatefulWidget {
  const AccountOptionPage({super.key, this.startupError});
  final String? startupError;

  @override
  ConsumerState<AccountOptionPage> createState() => _AccountOptionPageState();
}

class _AccountOptionPageState extends ConsumerState<AccountOptionPage> {
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
        setState(() => error = 'Unable to start Guest Mode. Please try again.');
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
                  const BrandMark(),
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
                    style: TextStyle(color: AppColors.muted, height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xff3d3930)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.rocket_launch_outlined,
                          color: AppColors.gold,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Guest Mode includes the dashboard, history, manual transactions, and 2 AI trials.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((error ?? widget.startupError) != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      (error ?? widget.startupError)!,
                      style: const TextStyle(color: AppColors.coral),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: loading ? null : _tryNow,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.ink,
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
                    style: secondaryButtonStyle(),
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

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.error});
  final String? error;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final controllers = List.generate(5, (_) => TextEditingController());
  bool register = false;
  bool loading = false;
  String? error;

  bool get upgradingGuest => ref.read(sessionProvider).value?.isGuest == true;

  @override
  void initState() {
    super.initState();
    register = ref.read(sessionProvider).value?.isGuest == true;
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = ref.read(apiProvider);
      if (register) {
        if (controllers[3].text != controllers[4].text) {
          throw Exception('Password confirmation does not match.');
        }
        await api.register(
          name: controllers[0].text,
          username: controllers[1].text,
          email: controllers[2].text,
          password: controllers[3].text,
          preserveGuest: upgradingGuest,
        );
        final session = await api.login(
          controllers[1].text,
          controllers[3].text,
        );
        await ref.read(sessionStoreProvider).save(session);
      } else {
        final session = await api.login(
          controllers[0].text,
          controllers[1].text,
        );
        await ref.read(sessionStoreProvider).save(session);
      }
      ref.read(showAuthProvider.notifier).state = false;
      ref.invalidate(sessionProvider);
      ref.invalidate(dashboardProvider);
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = exception is DioException
              ? _messageFromDio(exception)
              : exception.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = register
        ? ['Full name', 'Username', 'Email', 'Password', 'Confirm password']
        : ['Username', 'Password'];
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Back to start options',
                        onPressed: loading
                            ? null
                            : () => ref.read(showAuthProvider.notifier).state =
                                  false,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const BrandMark(),
                    const SizedBox(height: 22),
                    Text(
                      register
                          ? upgradingGuest
                                ? 'Save your guest history.'
                                : 'Create your account.'
                          : 'Welcome back.',
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      register && upgradingGuest
                          ? 'Your existing transactions will stay connected to this account.'
                          : 'One place for every spending story.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 22),
                    ...List.generate(
                      labels.length,
                      (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: controllers[index],
                          obscureText: labels[index].toLowerCase().contains(
                            'password',
                          ),
                          decoration: appInputDecoration(labels[index]),
                        ),
                      ),
                    ),
                    if ((error ?? widget.error) != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          (error ?? widget.error)!,
                          style: const TextStyle(color: AppColors.coral),
                        ),
                      ),
                    FilledButton(
                      onPressed: loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size(0, 54),
                      ),
                      child: Text(
                        loading
                            ? 'Processing...'
                            : register
                            ? 'Create account  >'
                            : 'Sign in  >',
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
                            ? 'Already have an account? Sign in'
                            : 'New here? Register',
                        style: const TextStyle(color: AppColors.cream),
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

String _messageFromDio(DioException error) {
  final data = error.response?.data;
  if (data is Map && data['message'] is String) {
    return data['message'] as String;
  }
  return 'Unable to connect to the server.';
}
