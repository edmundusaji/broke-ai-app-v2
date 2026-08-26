import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'pages/app_boot_page.dart';
import 'pages/app_lock_page.dart';
import 'pages/app_lock_recovery_page.dart';
import 'pages/history_page.dart';
import 'pages/home_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/profile_page.dart';
import 'pages/register_page.dart';
import 'pages/scan_page.dart';
import 'providers/app_providers.dart';
import 'widgets/manual_transaction_sheet.dart';

class BrokeAiApp extends ConsumerWidget {
  const BrokeAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'Broke.AI',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    darkTheme: buildDarkAppTheme(),
    themeMode: ref.watch(themeModeProvider),
    home: const AuthGate(),
    routes: {'/history': (_) => const HistoryPage()},
  );
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate>
    with WidgetsBindingObserver {
  bool _minimumBootTimeElapsed = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _minimumBootTimeElapsed = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(synchronizeTransactions(ref));
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      if (backgroundedAt == null) return;
      final settings = ref.read(appLockSettingsProvider).value;
      if (settings?.enabled == true &&
          DateTime.now().difference(backgroundedAt) >= settings!.lockDelay) {
        ref.read(appUnlockedProvider.notifier).state = false;
      }
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_minimumBootTimeElapsed) return const AppBootPage();
    final showAuth = ref.watch(showAuthProvider);
    final lockRecovery = ref.watch(appLockRecoveryProvider);
    final lockSettings = ref.watch(appLockSettingsProvider);
    return ref
        .watch(sessionProvider)
        .when(
          loading: () => const AppBootPage(),
          error: (_, _) => const OnboardingPage(
            startupError: 'Unable to restore your session. Please try again.',
          ),
          data: (session) {
            if (showAuth) return const RegisterPage();
            if (session?.isGuest == true &&
                !ref.read(sessionStoreProvider).guestEntryConfirmed) {
              return const OnboardingPage();
            }
            if (session != null) {
              if (lockRecovery == AppLockRecoveryStep.chooseAction) {
                return const AppLockRecoveryChoicePage();
              }
              if (lockRecovery == AppLockRecoveryStep.changePin) {
                return const AppLockChangePinPage();
              }
              final unlocked = ref.watch(appUnlockedProvider);
              if (unlocked) return const AppShell();
              return lockSettings.when(
                loading: () => const AppBootPage(),
                error: (_, _) => const AppShell(),
                data: (settings) {
                  if (settings.enabled) {
                    return const AppLockPage();
                  }
                  return const AppShell();
                },
              );
            }
            return const OnboardingPage();
          },
        );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int page = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => synchronizeTransactions(ref));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accountPreferencesProvider, (previous, next) {
      next.whenData((preferences) {
        final mode = switch (preferences.themeMode) {
          'dark' => ThemeMode.dark,
          'system' => ThemeMode.system,
          _ => ThemeMode.light,
        };
        if (ref.read(themeModeProvider) != mode) {
          Future<void>.microtask(
            () => ref.read(themeModeProvider.notifier).state = mode,
          );
        }
        final locale = ref.read(localePreferencesProvider);
        if (locale.currencyCode != preferences.currencyCode) {
          Future<void>.microtask(
            () => ref.read(localePreferencesProvider.notifier).state = locale
                .copyWith(currencyCode: preferences.currencyCode),
          );
        }
      });
    });
    ref.watch(accountPreferencesProvider);
    const pages = [HomePage(), ScanPage(), ProfilePage()];
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: page, children: pages),
      floatingActionButton: page == 0
          ? Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xff8a4df8), Color(0xff278df5)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x405b50f6),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton(
                tooltip: 'Add manual transaction',
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const ManualTransactionSheet(),
                ),
                child: const Icon(Icons.add_rounded, size: 29),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140f172a),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: page == 1
                ? const Color(0xffffbf30)
                : const Color(0xfff0edff),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? page == 1
                          ? colors.onSurface
                          : colors.primary
                    : colors.onSurfaceVariant,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                color: states.contains(WidgetState.selected)
                    ? page == 1
                          ? colors.onSurface
                          : colors.primary
                    : colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: page,
            onDestinationSelected: (index) => setState(() => page = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.document_scanner_outlined),
                selectedIcon: Icon(Icons.document_scanner_rounded),
                label: 'Scan',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
