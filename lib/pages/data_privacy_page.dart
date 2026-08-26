import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/account_settings.dart';
import '../providers/app_providers.dart';
import '../services/api_client.dart';
import '../widgets/settings_components.dart';

class DataPrivacyPage extends ConsumerStatefulWidget {
  const DataPrivacyPage({super.key});

  @override
  ConsumerState<DataPrivacyPage> createState() => _DataPrivacyPageState();
}

class _DataPrivacyPageState extends ConsumerState<DataPrivacyPage> {
  PrivacyPreferences? _privacy;
  SyncStatus? _sync;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        ref.read(settingsRepositoryProvider).privacyPreferences(),
        ref.read(settingsRepositoryProvider).syncStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _privacy = results[0] as PrivacyPreferences;
        _sync = results[1] as SyncStatus;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePrivacy({
    bool? personalizedInsights,
    bool? anonymousAnalytics,
  }) async {
    final current = _privacy;
    if (current == null || _busy) return;
    setState(() => _busy = true);
    try {
      final value = await ref
          .read(settingsRepositoryProvider)
          .updatePrivacyPreferences(
            current: current,
            personalizedInsights: personalizedInsights,
            anonymousAnalytics: anonymousAnalytics,
          );
      if (mounted) setState(() => _privacy = value);
    } catch (_) {
      if (mounted) {
        _message(
          'Could not save privacy settings on this device.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportData() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      var job = await ref.read(apiProvider).requestDataExport();
      for (
        var attempt = 0;
        attempt < 10 && (job.status == 'queued' || job.status == 'processing');
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 750));
        job = await ref.read(apiProvider).dataExport(job.jobId);
      }
      if (!mounted) return;
      if (job.status == 'ready') {
        final download = await ref.read(apiProvider).downloadDataExport(job);
        await SharePlus.instance.share(
          ShareParams(
            title: 'Broke.AI account data',
            text: 'Your Broke.AI account data export.',
            files: [
              XFile.fromData(download.bytes, mimeType: 'application/zip'),
            ],
            fileNameOverrides: [download.fileName],
          ),
        );
      } else if (job.status == 'failed') {
        _message(
          job.failureReason ?? 'The export could not be prepared.',
          error: true,
        );
      } else {
        _message('Your export is still being prepared. Try again shortly.');
      }
    } catch (error) {
      if (mounted) _message(apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearTransactions() async {
    final password = await _confirmWithPassword(
      title: 'Clear transaction history?',
      body:
          'All spending records will be removed. The backend keeps a seven-day recovery window.',
      action: 'Clear history',
    );
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final count = await ref.read(apiProvider).clearTransactions(password);
      await synchronizeTransactions(ref);
      ref.invalidate(dashboardProvider);
      ref.invalidate(syncStatusProvider);
      if (mounted) {
        _message('$count transaction${count == 1 ? '' : 's'} cleared.');
      }
    } catch (error) {
      if (mounted) _message(apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final password = await _confirmWithPassword(
      title: 'Delete account?',
      body:
          'Deletion is scheduled after a seven-day grace period. You will be signed out immediately.',
      action: 'Schedule deletion',
    );
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final scheduled = await ref
          .read(apiProvider)
          .requestAccountDeletion(password);
      final capture = ref.read(notificationCaptureServiceProvider);
      try {
        final status = await capture.status();
        if (status.deviceId != null) {
          await ref
              .read(apiProvider)
              .revokeNotificationCaptureDevice(status.deviceId!);
        }
      } catch (_) {
        // Account deletion continues even if the capture credential is stale.
      }
      await capture.clear(clearConsent: true);
      await ref.read(sessionStoreProvider).clear();
      ref.invalidate(sessionProvider);
      if (!mounted) return;
      final date = scheduled == null
          ? 'in seven days'
          : '${scheduled.toLocal().day}/${scheduled.toLocal().month}/${scheduled.toLocal().year}';
      _message('Account deletion scheduled for $date.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) _message(apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _confirmWithPassword({
    required String title,
    required String body,
    required String action,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(body),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(dialogContext, controller.text);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(action),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_loading) {
      return const SettingsPageScaffold(
        title: 'Data & privacy',
        subtitle:
            'Control your data, privacy choices, exports, and account removal.',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 72),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    final privacy = _privacy;
    if (privacy == null) return const SizedBox.shrink();
    return SettingsPageScaffold(
      title: 'Data & privacy',
      subtitle:
          'Control your data, privacy choices, exports, and account removal.',
      children: [
        SettingsInfoBanner(
          icon: _busy ? Icons.sync_rounded : Icons.lock_outline_rounded,
          title: _busy
              ? 'Completing your request…'
              : 'Your data belongs to you',
          body:
              'Privacy choices are saved on this device and synchronized with your account when available.',
          color: const Color(0xff2586f5),
        ),
        const SizedBox(height: 26),
        const SettingsSectionLabel('Your data'),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.cloud_done_outlined,
                color: const Color(0xff16a34a),
                title: 'Backup status',
                subtitle: _sync?.status == 'synced'
                    ? 'Synced with server'
                    : _sync?.status == 'local'
                    ? 'Saved on this device'
                    : (_sync?.status ?? 'Unknown'),
                showDivider: true,
              ),
              SettingsRow(
                icon: Icons.download_outlined,
                color: colors.primary,
                title: 'Export my data',
                subtitle: 'Download transactions and account data as ZIP.',
                showDivider: true,
                onTap: _busy ? null : _exportData,
              ),
              SettingsRow(
                icon: Icons.delete_sweep_outlined,
                color: const Color(0xffff9800),
                title: 'Clear transaction history',
                subtitle:
                    'Remove spending records without deleting your account.',
                onTap: _busy ? null : _clearTransactions,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SettingsSectionLabel('Privacy choices'),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.insights_outlined,
                color: colors.primary,
                title: 'Personalized insights',
                subtitle: 'Use spending patterns for tailored summaries.',
                showDivider: true,
                trailing: Switch(
                  value: privacy.personalizedInsights,
                  onChanged: _busy
                      ? null
                      : (enabled) =>
                            _updatePrivacy(personalizedInsights: enabled),
                ),
              ),
              SettingsRow(
                icon: Icons.analytics_outlined,
                color: const Color(0xff2586f5),
                title: 'Anonymous analytics',
                subtitle: 'Help improve app reliability and performance.',
                trailing: Switch(
                  value: privacy.anonymousAnalytics,
                  onChanged: _busy
                      ? null
                      : (enabled) =>
                            _updatePrivacy(anonymousAnalytics: enabled),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SettingsSectionLabel('Legal'),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.policy_outlined,
                color: colors.primary,
                title: 'Privacy policy',
                subtitle: 'Consent version ${privacy.policyVersion}',
                showDivider: true,
                onTap: () => _message(
                  'Privacy policy URL is not provided by the backend yet.',
                ),
              ),
              SettingsRow(
                icon: Icons.description_outlined,
                color: const Color(0xff65708e),
                title: 'Terms of service',
                onTap: () =>
                    _message('Terms URL is not provided by the backend yet.'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _busy ? null : _deleteAccount,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.error,
            side: BorderSide(color: colors.error.withValues(alpha: .45)),
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text(
            'Delete account',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
