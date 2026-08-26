import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_settings.dart';
import '../providers/app_providers.dart';
import '../services/api_client.dart';
import '../services/notification_capture_service.dart';
import '../widgets/settings_components.dart';

class NotificationsSettingsPage extends ConsumerStatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  ConsumerState<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState
    extends ConsumerState<NotificationsSettingsPage>
    with WidgetsBindingObserver {
  NotificationPreferences? _preferences;
  NotificationCaptureStatus _capture =
      const NotificationCaptureStatus.unsupported();
  bool _loading = true;
  bool _saving = false;
  bool _captureBusy = false;
  bool _finishEnableOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _refreshCapture().then((_) {
      if (_finishEnableOnResume && _capture.accessGranted) {
        _finishEnableOnResume = false;
        _provisionCapture();
      }
    });
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        ref.read(settingsRepositoryProvider).notificationPreferences(),
        ref.read(notificationCaptureServiceProvider).status(),
      ]);
      if (mounted) {
        setState(() {
          _preferences = results[0] as NotificationPreferences;
          _capture = results[1] as NotificationCaptureStatus;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshCapture() async {
    final value = await ref.read(notificationCaptureServiceProvider).status();
    if (mounted) setState(() => _capture = value);
  }

  Future<void> _enableCapture() async {
    if (_captureBusy) return;
    final accepted = _capture.consentAccepted || await _showDisclosure();
    if (!accepted || !mounted) return;
    await ref.read(notificationCaptureServiceProvider).setConsent(true);
    if (_capture.accessGranted) {
      await _provisionCapture();
      return;
    }
    _finishEnableOnResume = true;
    await ref.read(notificationCaptureServiceProvider).openSettings();
  }

  Future<bool> _showDisclosure() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.notifications_active_outlined),
          title: const Text('Enable automatic expense capture?'),
          content: const SingleChildScrollView(
            child: Text(
              'Broke.AI will read notifications from the financial apps you select, even while Broke.AI is closed. Eligible notification text is sent to the Broke.AI server and its disclosed AI processor only to extract expense details.\n\nRaw notification text is encrypted while waiting on this device, deleted after processing, and is not stored in the Broke.AI database. You can disable access at any time, and manual expense entry remains available.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('I understand'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _provisionCapture() async {
    if (_captureBusy || !mounted) return;
    setState(() => _captureBusy = true);
    try {
      final api = ref.read(apiProvider);
      final provision = await api.provisionNotificationCaptureDevice(
        deviceId: _capture.deviceId,
      );
      final selected = _capture.selectedSources.isEmpty
          ? _capture.sources.map((source) => source.packageName).toSet()
          : _capture.selectedSources;
      await ref
          .read(notificationCaptureServiceProvider)
          .configure(
            baseUrl: await api.resolvedBaseUrl(),
            credential: provision.captureCredential,
            deviceId: provision.deviceId,
            selectedSources: selected,
          );
      await _refreshCapture();
      if (mounted) _message('Automatic expense capture is on.');
    } catch (error) {
      if (mounted) _message(apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _captureBusy = false);
    }
  }

  Future<void> _disableCapture() async {
    if (_captureBusy) return;
    setState(() => _captureBusy = true);
    try {
      final deviceId = _capture.deviceId;
      if (deviceId != null) {
        try {
          await ref.read(apiProvider).revokeNotificationCaptureDevice(deviceId);
        } catch (_) {
          // Local capture still has to stop immediately when the user opts out.
        }
      }
      await ref.read(notificationCaptureServiceProvider).clear();
      await _refreshCapture();
      if (mounted) _message('Automatic expense capture is off.');
    } finally {
      if (mounted) setState(() => _captureBusy = false);
    }
  }

  Future<void> _toggleSource(String packageName, bool selected) async {
    final sources = {..._capture.selectedSources};
    if (selected) {
      sources.add(packageName);
    } else {
      sources.remove(packageName);
    }
    if (sources.isEmpty) {
      _message('Keep at least one payment app selected.', error: true);
      return;
    }
    await ref.read(notificationCaptureServiceProvider).updateSources(sources);
    await _refreshCapture();
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

  Future<void> _update({
    bool? spendingReminderEnabled,
    String? reminderTime,
    bool? weeklySummaryEnabled,
    bool? monthlyReportEnabled,
    bool? securityAlertsEnabled,
    bool? productUpdatesEnabled,
  }) async {
    final current = _preferences;
    if (current == null || _saving) return;
    setState(() => _saving = true);
    try {
      final value = await ref
          .read(settingsRepositoryProvider)
          .updateNotificationPreferences(
            current: current,
            spendingReminderEnabled: spendingReminderEnabled,
            reminderTime: reminderTime,
            weeklySummaryEnabled: weeklySummaryEnabled,
            monthlyReportEnabled: monthlyReportEnabled,
            securityAlertsEnabled: securityAlertsEnabled,
            productUpdatesEnabled: productUpdatesEnabled,
          );
      if (mounted) setState(() => _preferences = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not save notification settings on this device.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isGuest = ref.watch(sessionProvider).value?.isGuest ?? true;
    if (_loading) {
      return const SettingsPageScaffold(
        title: 'Notifications',
        subtitle:
            'Choose the reminders and account updates that matter to you.',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 72),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    final value = _preferences;
    if (value == null) return const SizedBox.shrink();
    final reminderTime = value.reminderTime.substring(0, 5);
    return SettingsPageScaffold(
      title: 'Notifications',
      subtitle: isGuest
          ? 'Choose the reminders that matter on this device.'
          : 'Choose the reminders and account updates that matter to you.',
      children: [
        SettingsInfoBanner(
          icon: Icons.notifications_active_outlined,
          title: _saving
              ? 'Saving preferences…'
              : 'Stay informed, not overwhelmed',
          body: isGuest
              ? 'Your choices are saved for this guest profile on this device.'
              : 'Your choices are saved on this device and synced when available.',
          color: const Color(0xffff9800),
        ),
        if (_capture.supported) ...[
          const SizedBox(height: 26),
          const SettingsSectionLabel('Automatic capture'),
          _AutomaticCaptureCard(
            status: _capture,
            isGuest: isGuest,
            busy: _captureBusy,
            onChanged: isGuest
                ? null
                : (enabled) => enabled ? _enableCapture() : _disableCapture(),
            onOpenSettings: () =>
                ref.read(notificationCaptureServiceProvider).openSettings(),
            onReconnect: _provisionCapture,
            onRetry: () async {
              await ref.read(notificationCaptureServiceProvider).retryPending();
              await _refreshCapture();
            },
            onSourceChanged: _toggleSource,
          ),
        ],
        const SizedBox(height: 26),
        const SettingsSectionLabel('Spending'),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.receipt_long_outlined,
                color: const Color(0xffff9800),
                title: 'Spending reminders',
                subtitle: 'Remind me to record today’s expenses.',
                showDivider: true,
                trailing: Switch(
                  value: value.spendingReminderEnabled,
                  onChanged: _saving
                      ? null
                      : (enabled) => _update(spendingReminderEnabled: enabled),
                ),
              ),
              SettingsRow(
                icon: Icons.schedule_outlined,
                color: colors.primary,
                title: 'Reminder time',
                subtitle: reminderTime,
                onTap: value.spendingReminderEnabled && !_saving
                    ? () => _pickTime(reminderTime)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SettingsSectionLabel('Summaries'),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.date_range_outlined,
                color: const Color(0xff2586f5),
                title: 'Weekly summary',
                subtitle: 'A quick view of your week every Sunday.',
                showDivider: true,
                trailing: Switch(
                  value: value.weeklySummaryEnabled,
                  onChanged: _saving
                      ? null
                      : (enabled) => _update(weeklySummaryEnabled: enabled),
                ),
              ),
              SettingsRow(
                icon: Icons.bar_chart_rounded,
                color: const Color(0xff16a34a),
                title: 'Monthly report',
                subtitle: 'Monthly totals, categories, and insights.',
                trailing: Switch(
                  value: value.monthlyReportEnabled,
                  onChanged: _saving
                      ? null
                      : (enabled) => _update(monthlyReportEnabled: enabled),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SettingsSectionLabel(isGuest ? 'App' : 'Account'),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              if (!isGuest)
                SettingsRow(
                  icon: Icons.shield_outlined,
                  color: colors.primary,
                  title: 'Security alerts',
                  subtitle: 'New sign-ins and important account changes.',
                  showDivider: true,
                  trailing: Switch(
                    value: value.securityAlertsEnabled,
                    onChanged: _saving
                        ? null
                        : (enabled) => _update(securityAlertsEnabled: enabled),
                  ),
                ),
              SettingsRow(
                icon: Icons.auto_awesome_outlined,
                color: const Color(0xff65708e),
                title: 'Product updates',
                subtitle: 'Occasional news about useful features.',
                trailing: Switch(
                  value: value.productUpdatesEnabled,
                  onChanged: _saving
                      ? null
                      : (enabled) => _update(productUpdatesEnabled: enabled),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime(String reminderTime) async {
    final parts = reminderTime.split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts.first),
        minute: int.parse(parts.last),
      ),
    );
    if (time != null) {
      await _update(
        reminderTime:
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00',
      );
    }
  }
}

class _AutomaticCaptureCard extends StatelessWidget {
  const _AutomaticCaptureCard({
    required this.status,
    required this.isGuest,
    required this.busy,
    required this.onChanged,
    required this.onOpenSettings,
    required this.onReconnect,
    required this.onRetry,
    required this.onSourceChanged,
  });

  final NotificationCaptureStatus status;
  final bool isGuest;
  final bool busy;
  final ValueChanged<bool>? onChanged;
  final VoidCallback onOpenSettings;
  final VoidCallback onReconnect;
  final VoidCallback onRetry;
  final Future<void> Function(String packageName, bool selected)
  onSourceChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = status.active;
    final stateText = isGuest
        ? 'Create an account to capture payment notifications automatically.'
        : status.needsReconnect
        ? 'Reconnect Broke.AI to continue uploading captured expenses.'
        : !status.accessGranted && status.enabled
        ? 'Notification Access was revoked. New expenses are not being captured.'
        : active
        ? '${status.selectedSources.length} payment app${status.selectedSources.length == 1 ? '' : 's'} selected.'
        : 'Read selected payment notifications and add valid expenses to history.';
    return SettingsCard(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Column(
        children: [
          SettingsRow(
            icon: active
                ? Icons.auto_awesome_rounded
                : Icons.notifications_none_rounded,
            color: active ? const Color(0xff16a34a) : colors.primary,
            title: 'Automatic expense capture',
            subtitle: stateText,
            trailing: busy
                ? const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Switch(value: status.enabled, onChanged: onChanged),
          ),
          if (!isGuest && status.enabled) ...[
            Divider(color: colors.outlineVariant),
            _CaptureStatusLine(
              icon: status.accessGranted
                  ? Icons.verified_user_outlined
                  : Icons.warning_amber_rounded,
              label: status.accessGranted
                  ? 'Notification Access granted'
                  : 'Notification Access required',
              color: status.accessGranted
                  ? const Color(0xff16a34a)
                  : colors.error,
              action: status.accessGranted
                  ? null
                  : TextButton(
                      onPressed: onOpenSettings,
                      child: const Text('Open settings'),
                    ),
            ),
            if (status.needsReconnect)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: busy ? null : onReconnect,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Reconnect'),
                ),
              ),
            if (status.queueCount > 0)
              _CaptureStatusLine(
                icon: Icons.cloud_upload_outlined,
                label:
                    '${status.queueCount} captured notification${status.queueCount == 1 ? '' : 's'} waiting to upload',
                color: const Color(0xffff9800),
                action: TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PAYMENT APPS',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .45,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ...status.sources.map(
              (source) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.trailing,
                value: status.selectedSources.contains(source.packageName),
                title: Text(
                  source.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  source.packageName,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                onChanged: busy
                    ? null
                    : (selected) => onSourceChanged(
                        source.packageName,
                        selected ?? false,
                      ),
              ),
            ),
            if (status.lastResult != null)
              _CaptureStatusLine(
                icon: Icons.history_rounded,
                label: 'Last result: ${status.lastResult!.toLowerCase()}',
                color: colors.onSurfaceVariant,
              ),
            if (status.lastError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  status.lastError!,
                  style: TextStyle(color: colors.error, fontSize: 12.5),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CaptureStatusLine extends StatelessWidget {
  const _CaptureStatusLine({
    required this.icon,
    required this.label,
    required this.color,
    this.action,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 9),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
        ?action,
      ],
    ),
  );
}
