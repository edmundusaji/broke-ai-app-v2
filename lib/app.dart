import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'pages/history_page.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/register_page.dart';
import 'pages/scan_page.dart';
import 'pages/try_now_page.dart';
import 'providers/app_providers.dart';
import 'widgets/manual_transaction_sheet.dart';

class BrokeAiApp extends StatelessWidget {
  const BrokeAiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Broke.AI',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const AuthGate(),
    routes: {'/history': (_) => const HistoryPage()},
  );
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showAuth = ref.watch(showAuthProvider);
    return ref
        .watch(sessionProvider)
        .when(
          loading: () => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent),
            ),
          ),
          error: (_, _) => const AccountOptionPage(
            startupError: 'Unable to restore your session. Please try again.',
          ),
          data: (session) {
            if (showAuth) return const RegisterPage();
            if (session != null) return const AppShell();
            return const AccountOptionPage();
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
  Widget build(BuildContext context) {
    const pages = [HomePage(), ScanPage(), ProfilePage()];
    return Scaffold(
      body: IndexedStack(index: page, children: pages),
      floatingActionButton: page == 0
          ? FloatingActionButton(
              tooltip: 'Add manual transaction',
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: Colors.white,
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
          color: AppColors.surfaceCard,
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          boxShadow: [
            BoxShadow(
              color: Color(0x140f172a),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0x145b50f6),
          selectedIndex: page,
          onDestinationSelected: (index) => setState(() => page = index),
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
