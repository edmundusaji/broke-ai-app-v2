import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../providers/app_providers.dart';
import '../widgets/surface_card.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _openAuth(WidgetRef ref) {
    ref.read(showAuthProvider.notifier).state = true;
  }

  Future<void> _logout(WidgetRef ref) async {
    ref.read(showAuthProvider.notifier).state = false;
    await ref.read(sessionStoreProvider).clear();
    ref.invalidate(sessionProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final isGuest = session?.isGuest == true;
    final username = session?.username ?? '';
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 108),
        children: [
          const Text(
            'Profile & Settings',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'Manage your account, preferences, and app settings.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 18),
          _UserCard(
            name: session?.displayName ?? 'Broke.AI User',
            username: username,
            initials: session?.initials ?? 'BA',
            isGuest: isGuest,
            onCopy: username.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: username));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Username copied.')),
                      );
                    }
                  },
          ),
          if (isGuest) ...[
            const SizedBox(height: 16),
            _GuestSaveBanner(onRegister: () => _openAuth(ref)),
          ],
          const SizedBox(height: 22),
          const _SectionLabel('ACCOUNT'),
          const SizedBox(height: 8),
          const SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Manage profile',
                  color: AppColors.primaryAccent,
                ),
                _SettingDivider(),
                _SettingTile(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  color: Color(0xffff9800),
                ),
                _SettingDivider(),
                _SettingTile(
                  icon: Icons.language_rounded,
                  label: 'Server settings',
                  color: Color(0xff16a34a),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SectionLabel('SUPPORT'),
          const SizedBox(height: 8),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const _SettingTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & FAQ',
                  color: AppColors.primaryAccent,
                ),
                const _SettingDivider(),
                const _SettingTile(
                  icon: Icons.bug_report_outlined,
                  label: 'Report a bug',
                  color: Color(0xffff5f45),
                ),
                const _SettingDivider(),
                if (isGuest)
                  _SettingTile(
                    icon: Icons.login_rounded,
                    label: 'Login / Register',
                    color: const Color(0xff159ac7),
                    onTap: () => _openAuth(ref),
                  )
                else
                  _SettingTile(
                    icon: Icons.logout_rounded,
                    label: 'Log out',
                    color: AppColors.danger,
                    danger: true,
                    onTap: () => _logout(ref),
                  ),
              ],
            ),
          ),
          if (isGuest) ...[
            const SizedBox(height: 18),
            _GuestLocalNotice(onRegister: () => _openAuth(ref)),
          ],
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.name,
    required this.username,
    required this.initials,
    required this.isGuest,
    required this.onCopy,
  });

  final String name;
  final String username;
  final String initials;
  final bool isGuest;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xfffaf4ff), Colors.white, Color(0xfff0f8ff)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.borderSubtle),
      boxShadow: const [
        BoxShadow(
          color: Color(0x120f172a),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffffc342), Color(0xffffb52e)],
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x305b50f6),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xff071653),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  if (onCopy != null)
                    IconButton(
                      tooltip: 'Copy username',
                      onPressed: onCopy,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xfff0eaff),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGuest
                          ? Icons.person_outline_rounded
                          : Icons.verified_user_outlined,
                      color: AppColors.primaryAccent,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isGuest ? 'Guest mode' : 'Account',
                      style: const TextStyle(
                        color: AppColors.primaryAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        const Icon(
          Icons.auto_awesome_rounded,
          color: Color(0xffb29cff),
          size: 30,
        ),
      ],
    ),
  );
}

class _GuestSaveBanner extends StatelessWidget {
  const _GuestSaveBanner({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    decoration: BoxDecoration(
      color: const Color(0xfffffdf7),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xffffd77a)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 58,
          height: 58,
          child: Image.asset(
            AppAssets.profileSecurityShield,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Save your transaction history',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 5),
              Text(
                'Create an account to securely save and sync your guest transaction history.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: Color(0xffa06f2a),
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Your data stays private and secure.',
                      style: TextStyle(
                        color: Color(0xff8a6331),
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        FilledButton(
          onPressed: onRegister,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xffffbf30),
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Save & Register',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xff4d5878),
      fontSize: 13,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 22),
    ),
    title: Text(
      label,
      style: TextStyle(
        color: danger ? AppColors.danger : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
    trailing: Icon(
      Icons.chevron_right_rounded,
      color: danger ? AppColors.danger : const Color(0xff65708e),
    ),
  );
}

class _SettingDivider extends StatelessWidget {
  const _SettingDivider();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    indent: 68,
    endIndent: 14,
    color: AppColors.borderSubtle,
  );
}

class _GuestLocalNotice extends StatelessWidget {
  const _GuestLocalNotice({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.info_outline_rounded, color: Color(0xff2586f5)),
      const SizedBox(width: 10),
      Expanded(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Guest data is stored locally on this device. ',
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
            GestureDetector(
              onTap: onRegister,
              child: const Text(
                'Create an account',
                style: TextStyle(
                  color: AppColors.primaryAccent,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ),
            const Text(
              ' to back up and sync across devices.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      const Icon(
        Icons.cloud_upload_outlined,
        color: AppColors.primaryAccent,
        size: 34,
      ),
    ],
  );
}
