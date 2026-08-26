import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import 'about_page.dart';
import 'currency_language_page.dart';
import 'data_privacy_page.dart';
import 'help_faq_page.dart';
import 'manage_profile_page.dart';
import 'notifications_settings_page.dart';
import '../providers/app_providers.dart';
import 'security_page.dart';
import '../widgets/appearance_sheet.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _openAuth(WidgetRef ref, {bool signIn = false}) {
    ref.read(authStartInLoginProvider.notifier).state = signIn;
    ref.read(showAuthProvider.notifier).state = true;
  }

  Future<void> _clearGuestHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_outlined),
        title: const Text('Clear guest history?'),
        content: const Text(
          'This removes every transaction linked to this guest session. Your guest identity and preferences will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final session = await ref.read(sessionProvider.future);
      if (session == null) throw StateError('No local account is active.');
      final repository = await ref.read(transactionRepositoryProvider.future);
      final count = await repository.clearTransactions(session.accountScope);
      ref.invalidate(dashboardProvider);
      ref.invalidate(localTransactionSyncStatusProvider);
      unawaited(synchronizeTransactions(ref));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$count transaction${count == 1 ? '' : 's'} cleared.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) _showGuestControlUnavailable(context);
    }
  }

  Future<void> _deleteGuestData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteGuestDialog(),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final session = await ref.read(sessionProvider.future);
      await ref.read(apiProvider).deleteGuestAccount();
      if (session != null) {
        final repository = await ref.read(transactionRepositoryProvider.future);
        await repository.clearAccount(session.accountScope);
      }
      await ref
          .read(notificationCaptureServiceProvider)
          .clear(clearConsent: true);
      await ref.read(sessionStoreProvider).clear();
      ref.read(showAuthProvider.notifier).state = false;
      ref.read(authStartInLoginProvider.notifier).state = false;
      ref.invalidate(sessionProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(accountPreferencesProvider);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {
      if (context.mounted) _showGuestControlUnavailable(context);
    }
  }

  void _showGuestControlUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This guest data control is not available on the connected server yet. No data was changed.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout(WidgetRef ref) async {
    ref.read(showAuthProvider.notifier).state = false;
    final capture = ref.read(notificationCaptureServiceProvider);
    try {
      final status = await capture.status();
      if (status.deviceId != null) {
        await ref
            .read(apiProvider)
            .revokeNotificationCaptureDevice(status.deviceId!);
      }
    } catch (_) {
      // Logout must still remove local capture access while offline.
    }
    await capture.clear(clearConsent: true);
    await ref.read(sessionStoreProvider).clear();
    ref.read(appUnlockedProvider.notifier).state = false;
    ref.read(appLockRecoveryProvider.notifier).state = AppLockRecoveryStep.none;
    ref.read(themeModeProvider.notifier).state = ThemeMode.light;
    ref.invalidate(sessionProvider);
    ref.invalidate(accountPreferencesProvider);
    ref.invalidate(syncStatusProvider);
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _showSettingDetails(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final isGuest = session?.isGuest ?? true;
    final username = session?.username ?? '';
    final profileDraft = ref.watch(profileDraftProvider);
    final email = (session?.email?.trim().isNotEmpty ?? false)
        ? session!.email!.trim()
        : username.isNotEmpty
        ? '@$username'
        : 'Signed-in account';
    final displayName =
        profileDraft?.fullName ?? session?.displayName ?? username;
    final displayEmail = profileDraft?.email ?? email;
    final locale = ref.watch(localePreferencesProvider);
    final darkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
    final sync = isGuest ? null : ref.watch(syncStatusProvider).value;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 108),
        children: [
          Text(
            'Profile & Settings',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isGuest
                ? 'Protect your guest data and personalize this device.'
                : 'Manage your account, preferences, and app settings.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          if (isGuest)
            _GuestIdentityCard(
              onDetails: () => _showSettingDetails(
                context,
                icon: Icons.phonelink_rounded,
                color: AppColors.primaryAccent,
                title: 'Linked to this device',
                description:
                    'Your transactions are stored under a temporary guest identity. Access depends on the secure guest session held by this device.',
              ),
            )
          else
            _AccountIdentityHeader(
              name: displayName,
              email: displayEmail,
              initials: _initials(displayName),
              onTap: () => _openPage(context, const ManageProfilePage()),
            ),
          if (isGuest) ...[
            const SizedBox(height: 16),
            _GuestProtectionCard(
              onCreateAccount: () => _openAuth(ref),
              onSignIn: () => _openAuth(ref, signIn: true),
            ),
            const SizedBox(height: 16),
            _GuestAiAllowanceCard(
              remaining: session?.remainingAiTrials ?? 0,
              onCreateAccount: () => _openAuth(ref),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('APP PREFERENCES'),
            const SizedBox(height: 6),
            _FlatSettingsGroup(
              children: [
                _FlatSettingTile(
                  icon: Icons.language_rounded,
                  label: 'Currency & language',
                  color: const Color(0xff16a34a),
                  trailingText: locale.currencyCode,
                  onTap: () => _openPage(context, const CurrencyLanguagePage()),
                ),
                _FlatSettingTile(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  color: const Color(0xffff9800),
                  onTap: () =>
                      _openPage(context, const NotificationsSettingsPage()),
                ),
                _FlatSettingTile(
                  icon: Icons.dark_mode_outlined,
                  label: 'Appearance',
                  color: AppColors.primaryAccent,
                  trailingText: darkMode ? 'Dark' : 'Light',
                  onTap: () => showAppearanceSheet(context),
                ),
                _FlatSettingTile(
                  icon: Icons.phonelink_lock_outlined,
                  label: 'App lock',
                  color: const Color(0xff2586f5),
                  onTap: () => _openPage(
                    context,
                    const SecurityPage(deviceLockOnly: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('DATA LINKED TO THIS DEVICE'),
            const SizedBox(height: 8),
            const _GuestDataContextCard(),
            const SizedBox(height: 8),
            _FlatSettingsGroup(
              children: [
                _FlatSettingTile(
                  icon: Icons.delete_sweep_outlined,
                  label: 'Clear transaction history',
                  color: const Color(0xffff9800),
                  onTap: () => _clearGuestHistory(context, ref),
                ),
                _FlatSettingTile(
                  icon: Icons.delete_forever_outlined,
                  label: 'Delete guest data',
                  color: Theme.of(context).colorScheme.error,
                  onTap: () => _deleteGuestData(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('HELP & SUPPORT'),
            const SizedBox(height: 6),
            _FlatSettingsGroup(
              children: [
                _FlatSettingTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & FAQ',
                  color: AppColors.primaryAccent,
                  onTap: () => _openPage(context, const HelpFaqPage()),
                ),
                _FlatSettingTile(
                  icon: Icons.bug_report_outlined,
                  label: 'Report a bug',
                  color: const Color(0xffff5f45),
                  onTap: () => _openPage(
                    context,
                    const HelpFaqPage(openBugReport: true),
                  ),
                ),
                _FlatSettingTile(
                  icon: Icons.info_outline_rounded,
                  label: 'About',
                  color: const Color(0xff65708e),
                  onTap: () => _openPage(context, const AboutPage()),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 28),
            _SyncProtectionCard(
              statusText: sync?.status == 'synced'
                  ? 'Synced with server'
                  : sync?.status == 'local'
                  ? 'Saved on this device'
                  : sync?.status ?? 'Checking sync status…',
              onTap: () => _showSettingDetails(
                context,
                icon: Icons.cloud_done_outlined,
                color: AppColors.primaryAccent,
                title: 'Backup & sync',
                description: sync?.status == 'synced'
                    ? 'Your account data is protected and the latest changes are synced.'
                    : 'Your settings are safe on this device and will sync when the account service is available.',
              ),
            ),
            const SizedBox(height: 28),
            const _SectionLabel('PERSONAL'),
            const SizedBox(height: 6),
            _FlatSettingsGroup(
              children: [
                _FlatSettingTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Manage profile',
                  color: AppColors.primaryAccent,
                  onTap: () => _openPage(context, const ManageProfilePage()),
                ),
                _FlatSettingTile(
                  icon: Icons.shield_outlined,
                  label: 'Security',
                  color: AppColors.primaryAccent,
                  onTap: () => _openPage(context, const SecurityPage()),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('APP PREFERENCES'),
            const SizedBox(height: 6),
            _FlatSettingsGroup(
              children: [
                _FlatSettingTile(
                  icon: Icons.language_rounded,
                  label: 'Currency & language',
                  color: const Color(0xff16a34a),
                  trailingText: locale.currencyCode,
                  onTap: () => _openPage(context, const CurrencyLanguagePage()),
                ),
                _FlatSettingTile(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  color: const Color(0xffff9800),
                  onTap: () =>
                      _openPage(context, const NotificationsSettingsPage()),
                ),
                _FlatSettingTile(
                  icon: Icons.dark_mode_outlined,
                  label: 'Appearance',
                  color: AppColors.primaryAccent,
                  trailingText: darkMode ? 'Dark' : 'Light',
                  onTap: () => showAppearanceSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('DATA & SUPPORT'),
            const SizedBox(height: 6),
            _FlatSettingsGroup(
              children: [
                _FlatSettingTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Data & privacy',
                  color: const Color(0xff2586f5),
                  onTap: () => _openPage(context, const DataPrivacyPage()),
                ),
                _FlatSettingTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & FAQ',
                  color: AppColors.primaryAccent,
                  onTap: () => _openPage(context, const HelpFaqPage()),
                ),
                _FlatSettingTile(
                  icon: Icons.info_outline_rounded,
                  label: 'About',
                  color: const Color(0xff65708e),
                  onTap: () => _openPage(context, const AboutPage()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _LogoutAction(onTap: () => _logout(ref)),
          ],
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'BA';
    return parts
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
  }
}

class _GuestIdentityCard extends StatelessWidget {
  const _GuestIdentityCard({required this.onDetails});

  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xff1c1938), Color(0xff151f35)]
              : const [Color(0xfff8f5ff), Color(0xfff3f9ff)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .13),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: colors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest mode',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phonelink_rounded,
                        size: 15,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Linked to this device',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'About guest mode',
            onPressed: onDetails,
            icon: Icon(Icons.info_outline_rounded, color: colors.primary),
          ),
        ],
      ),
    );
  }
}

class _GuestProtectionCard extends StatelessWidget {
  const _GuestProtectionCard({
    required this.onCreateAccount,
    required this.onSignIn,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.primary.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.cloud_done_outlined, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Protect your transaction history',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create an account to keep this guest history and access it after changing devices.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreateAccount,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
              label: const Text(
                'Create account',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: onSignIn,
              child: const Text('Already have an account? Sign in'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestAiAllowanceCard extends StatelessWidget {
  const _GuestAiAllowanceCard({
    required this.remaining,
    required this.onCreateAccount,
  });

  final int remaining;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final safeRemaining = remaining.clamp(0, 2);
    final exhausted = safeRemaining == 0;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: colors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'AI scans remaining',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$safeRemaining of 2',
                style: TextStyle(
                  color: exhausted ? colors.error : colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: safeRemaining / 2,
              backgroundColor: colors.surfaceContainerHighest,
              color: exhausted ? colors.error : colors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            exhausted
                ? 'Your guest AI allowance is used. Create an account to continue with account features.'
                : 'Guest scans are limited. Creating an account keeps your transaction history.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          if (exhausted) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onCreateAccount,
                child: const Text('Create account'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuestDataContextCard extends StatelessWidget {
  const _GuestDataContextCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colors.primary, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Transactions belong to a temporary guest identity. Access depends on the secure guest session on this device, and may be lost if app data is cleared, the app is reinstalled, or the session expires.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteGuestDialog extends StatefulWidget {
  const _DeleteGuestDialog();

  @override
  State<_DeleteGuestDialog> createState() => _DeleteGuestDialogState();
}

class _DeleteGuestDialogState extends State<_DeleteGuestDialog> {
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final valid = _confirmationController.text.trim() == 'DELETE';
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: colors.error),
      title: const Text('Delete all guest data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes this guest identity and its transaction history. This cannot be undone.',
          ),
          const SizedBox(height: 16),
          const Text('Type DELETE to confirm.'),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmationController,
            autofocus: true,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'DELETE'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          child: const Text('Delete guest data'),
        ),
      ],
    );
  }
}

class _AccountIdentityHeader extends StatelessWidget {
  const _AccountIdentityHeader({
    required this.name,
    required this.email,
    required this.initials,
    required this.onTap,
  });

  final String name;
  final String email;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Account for $name, $email. Free plan.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
                  border: Border.all(color: colors.surface, width: 5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x205b50f6),
                      blurRadius: 16,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff071653),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: colors.primary,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          const Text(
                            'Free plan',
                            style: TextStyle(
                              color: Color(0xff6f63ff),
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
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncProtectionCard extends StatelessWidget {
  const _SyncProtectionCard({required this.onTap, required this.statusText});

  final VoidCallback onTap;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: dark
              ? const [Color(0xff191831), Color(0xff161d33)]
              : const [Color(0xfffaf7ff), Color(0xfff7f8ff)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark ? const Color(0xff3d3973) : const Color(0xffddd5ff),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_done_outlined,
              color: AppColors.primaryAccent,
              size: 29,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your data is protected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.circle, color: Color(0xff22c55e), size: 10),
                    SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        statusText,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryAccent,
              minimumSize: const Size(0, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View backup',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlatSettingsGroup extends StatelessWidget {
  const _FlatSettingsGroup({required this.children});

  final List<_FlatSettingTile> children;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < children.length; index++) ...[
        children[index],
        if (index < children.length - 1)
          Divider(
            height: 1,
            indent: 60,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
      ],
    ],
  );
}

class _FlatSettingTile extends StatelessWidget {
  const _FlatSettingTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      minTileHeight: 66,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: colors.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText!,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _LogoutAction extends StatelessWidget {
  const _LogoutAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    minTileHeight: 66,
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(
        Icons.logout_rounded,
        color: AppColors.danger,
        size: 22,
      ),
    ),
    title: const Text(
      'Log out',
      style: TextStyle(
        color: AppColors.danger,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// Legacy account card retained while older golden tests are migrated.
// ignore: unused_element
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

// Legacy guest banner retained while older golden tests are migrated.
// ignore: unused_element
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
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 13,
      fontWeight: FontWeight.w800,
    ),
  );
}

// Legacy grouped tile retained while older golden tests are migrated.
// ignore: unused_element
class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    required this.color,
    // ignore: unused_element_parameter
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

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
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    trailing: Icon(
      Icons.chevron_right_rounded,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

// ignore: unused_element
class _SettingDivider extends StatelessWidget {
  const _SettingDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 68,
    endIndent: 14,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

// Legacy notice is kept only for golden-test compatibility.
// ignore: unused_element
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
