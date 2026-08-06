import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../providers/app_providers.dart';
import '../widgets/surface_card.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
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
                  backgroundColor: AppColors.gold,
                  child: Text(
                    session?.initials ?? 'BA',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  session?.displayName ?? 'Broke.AI User',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  session?.email ?? session?.username ?? '',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (session?.isGuest == true) ...[
            const SizedBox(height: 16),
            SurfaceCard(
              tint: const Color(0xfff5f3ff),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.gold),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Create an account to keep your guest transaction history.',
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(showAuthProvider.notifier).state = true,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Text(
            'Account',
            style: TextStyle(
              color: AppColors.cream,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const SurfaceCard(
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
            style: TextStyle(
              color: AppColors.cream,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const _SettingTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & FAQ',
                ),
                const _SettingTile(
                  icon: Icons.bug_report_outlined,
                  label: 'Report a bug',
                ),
                if (session?.isGuest == true)
                  _SettingTile(
                    icon: Icons.login_rounded,
                    label: 'Login / Register',
                    onTap: () =>
                        ref.read(showAuthProvider.notifier).state = true,
                  )
                else
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
    leading: Icon(icon, color: danger ? AppColors.danger : AppColors.gold),
    title: Text(
      label,
      style: TextStyle(color: danger ? AppColors.danger : AppColors.cream),
    ),
    trailing: Icon(
      Icons.arrow_forward_rounded,
      color: danger ? AppColors.danger : AppColors.muted,
    ),
  );
}
