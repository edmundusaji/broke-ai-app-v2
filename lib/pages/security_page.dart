import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_settings.dart';
import '../providers/app_providers.dart';
import '../services/app_lock_service.dart';
import '../services/api_client.dart';
import '../widgets/settings_components.dart';

class SecurityPage extends ConsumerStatefulWidget {
  const SecurityPage({super.key, this.deviceLockOnly = false});

  final bool deviceLockOnly;

  @override
  ConsumerState<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends ConsumerState<SecurityPage> {
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _currentVisible = false;
  bool _newVisible = false;
  bool _confirmVisible = false;
  bool _updating = false;
  List<AccountSession> _sessions = const [];
  bool _sessionsLoading = true;

  @override
  void initState() {
    super.initState();
    if (!widget.deviceLockOnly) _loadSessions();
  }

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  int get _passwordStrength {
    final value = _newPassword.text;
    var score = 0;
    if (value.length >= 15) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'\d').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }

  Future<void> _updatePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    setState(() => _updating = true);
    try {
      final revoked = await ref
          .read(apiProvider)
          .changePassword(
            currentPassword: _currentPassword.text,
            newPassword: _newPassword.text,
          );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      _message(
        revoked == 0
            ? 'Password updated.'
            : 'Password updated. $revoked other session${revoked == 1 ? '' : 's'} signed out.',
      );
      await _loadSessions();
    } catch (error) {
      if (mounted) _message(apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _loadSessions() async {
    setState(() => _sessionsLoading = true);
    try {
      final sessions = await ref.read(apiProvider).sessions();
      if (mounted) {
        setState(
          () => _sessions = sessions.where((item) => item.active).toList(),
        );
      }
    } catch (_) {
      // Session management is secondary to password and device lock controls.
    } finally {
      if (mounted) setState(() => _sessionsLoading = false);
    }
  }

  Future<void> _revokeOthers() async {
    try {
      await ref.read(apiProvider).revokeOtherSessions();
      await _loadSessions();
      if (mounted) _message('Other sessions signed out.');
    } catch (error) {
      if (mounted) _message(apiErrorMessage(error), error: true);
    }
  }

  Future<void> _revoke(AccountSession session) async {
    try {
      await ref.read(apiProvider).revokeSession(session.id);
      await _loadSessions();
      if (mounted) _message('Session signed out.');
    } catch (error) {
      if (mounted) _message(apiErrorMessage(error), error: true);
    }
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

  Future<void> _setAppLock(bool enabled) async {
    try {
      if (!enabled) {
        await ref.read(appLockServiceProvider).disable();
        ref.read(appUnlockedProvider.notifier).state = true;
        ref.invalidate(appLockSettingsProvider);
        return;
      }
      final pin = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _PinSetupSheet(),
      );
      if (pin == null) return;
      await ref.read(appLockServiceProvider).enable(pin);
      ref.read(appUnlockedProvider.notifier).state = true;
      ref.invalidate(appLockSettingsProvider);
      if (mounted) _message('App lock enabled for this device.');
    } catch (_) {
      if (mounted) {
        _message('Could not save app lock on this device.', error: true);
      }
    }
  }

  Future<void> _setBiometric(bool enabled) async {
    try {
      await ref.read(appLockServiceProvider).setBiometricEnabled(enabled);
      ref.invalidate(appLockSettingsProvider);
    } catch (_) {
      if (mounted) {
        _message('Could not update biometric unlock.', error: true);
      }
    }
  }

  InputDecoration _passwordDecoration(
    BuildContext context,
    String label,
    bool visible,
    VoidCallback toggle,
  ) =>
      settingsInputDecoration(
        context,
        label: label,
        icon: Icons.lock_outline_rounded,
      ).copyWith(
        suffixIcon: IconButton(
          tooltip: visible ? 'Hide password' : 'Show password',
          onPressed: toggle,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lockSettings = ref.watch(appLockSettingsProvider);
    final settings = lockSettings.value ?? const AppLockSettings.disabled();
    final appLock = settings.enabled;
    final biometric = settings.biometricEnabled;

    if (widget.deviceLockOnly) {
      return SettingsPageScaffold(
        title: 'App lock',
        subtitle: 'Protect access to Broke.AI on this device.',
        children: [
          const SettingsInfoBanner(
            icon: Icons.phonelink_lock_outlined,
            title: 'Device-only protection',
            body:
                'Your PIN and biometric choice stay in this device’s encrypted storage and are never sent to the server.',
            color: Color(0xff2586f5),
          ),
          const SizedBox(height: 26),
          const SettingsSectionLabel('Unlock settings'),
          SettingsCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Column(
              children: [
                SettingsRow(
                  icon: Icons.lock_outline_rounded,
                  color: colors.primary,
                  title: 'Require app lock',
                  subtitle: 'Use a 4-digit PIN to open Broke.AI.',
                  showDivider: appLock,
                  trailing: Switch(value: appLock, onChanged: _setAppLock),
                ),
                if (appLock) ...[
                  SettingsRow(
                    icon: Icons.fingerprint_rounded,
                    color: const Color(0xff2586f5),
                    title: 'Biometric unlock',
                    subtitle: 'Use fingerprint or face recognition.',
                    showDivider: true,
                    trailing: Switch(
                      value: biometric,
                      onChanged: _setBiometric,
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.timer_outlined,
                    color: const Color(0xffff9800),
                    title: 'Lock after',
                    subtitle: settings.lockAfter,
                    onTap: () => _showLockTiming(settings.lockAfter),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'App lock protects access on this phone. It does not create or secure an online account.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    return SettingsPageScaffold(
      title: 'Security',
      subtitle: 'Protect your account and decide how the app unlocks.',
      children: [
        SettingsInfoBanner(
          icon: Icons.verified_user_outlined,
          title: 'Your account is protected',
          body:
              'Use a strong password and turn on app lock when other people can access your phone.',
          color: const Color(0xff16a34a),
        ),
        const SizedBox(height: 26),
        const SettingsSectionLabel('Change password'),
        SettingsCard(
          child: Form(
            key: _passwordFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _currentPassword,
                  obscureText: !_currentVisible,
                  textInputAction: TextInputAction.next,
                  decoration: _passwordDecoration(
                    context,
                    'Current password',
                    _currentVisible,
                    () => setState(() => _currentVisible = !_currentVisible),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your current password.'
                      : null,
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _newPassword,
                  obscureText: !_newVisible,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: _passwordDecoration(
                    context,
                    'New password',
                    _newVisible,
                    () => setState(() => _newVisible = !_newVisible),
                  ),
                  validator: (value) => (value?.length ?? 0) < 15
                      ? 'Use a passphrase with at least 15 characters.'
                      : (value?.length ?? 0) > 128
                      ? 'Password must not exceed 128 characters.'
                      : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var index = 0; index < 4; index++) ...[
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 4,
                          decoration: BoxDecoration(
                            color: index < _passwordStrength
                                ? _strengthColor(_passwordStrength)
                                : colors.outlineVariant,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      if (index < 3) const SizedBox(width: 5),
                    ],
                    const SizedBox(width: 10),
                    Text(
                      _strengthLabel(_passwordStrength),
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _confirmPassword,
                  obscureText: !_confirmVisible,
                  textInputAction: TextInputAction.done,
                  decoration: _passwordDecoration(
                    context,
                    'Confirm new password',
                    _confirmVisible,
                    () => setState(() => _confirmVisible = !_confirmVisible),
                  ),
                  validator: (value) => value != _newPassword.text
                      ? 'Passwords do not match.'
                      : null,
                ),
                const SizedBox(height: 16),
                SettingsPrimaryButton(
                  label: 'Update password',
                  icon: Icons.shield_outlined,
                  loading: _updating,
                  onPressed: _updatePassword,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        const SettingsSectionLabel('App lock'),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.lock_outline_rounded,
                color: colors.primary,
                title: 'Require app lock',
                subtitle: 'Use a 4-digit PIN to open Broke.AI.',
                showDivider: appLock,
                trailing: Switch(value: appLock, onChanged: _setAppLock),
              ),
              if (appLock) ...[
                SettingsRow(
                  icon: Icons.fingerprint_rounded,
                  color: const Color(0xff2586f5),
                  title: 'Biometric unlock',
                  subtitle: 'Use fingerprint or face recognition.',
                  showDivider: true,
                  trailing: Switch(value: biometric, onChanged: _setBiometric),
                ),
                SettingsRow(
                  icon: Icons.timer_outlined,
                  color: const Color(0xffff9800),
                  title: 'Lock after',
                  subtitle: settings.lockAfter,
                  onTap: () => _showLockTiming(settings.lockAfter),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'App lock protects access on this phone. It does not replace your account password.',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 26),
        const SettingsSectionLabel('Active sessions'),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: _sessionsLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
                  children: [
                    if (_sessions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No active sessions found.'),
                      ),
                    for (var index = 0; index < _sessions.length; index++)
                      SettingsRow(
                        icon: _sessions[index].current
                            ? Icons.smartphone_rounded
                            : Icons.devices_rounded,
                        color: _sessions[index].current
                            ? const Color(0xff16a34a)
                            : colors.primary,
                        title:
                            _sessions[index].deviceName ??
                            (_sessions[index].current
                                ? 'This device'
                                : 'Signed-in device'),
                        subtitle: _sessions[index].current
                            ? 'Current session'
                            : (_sessions[index].userAgent ?? 'Active session'),
                        showDivider: index < _sessions.length - 1,
                        trailing: _sessions[index].current
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xff16a34a),
                              )
                            : IconButton(
                                tooltip: 'Sign out this session',
                                onPressed: () => _revoke(_sessions[index]),
                                icon: const Icon(Icons.logout_rounded),
                              ),
                      ),
                    if (_sessions
                        .where((item) => !item.current)
                        .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _revokeOthers,
                        icon: const Icon(Icons.phonelink_erase_rounded),
                        label: const Text('Sign out all other devices'),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  void _showLockTiming(String currentValue) {
    const options = ['Immediately', 'After 1 minute', 'After 5 minutes'];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lock timing',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              for (final option in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option),
                  trailing: option == currentValue
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () async {
                    await ref.read(appLockServiceProvider).setLockAfter(option);
                    ref.invalidate(appLockSettingsProvider);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _strengthColor(int score) => switch (score) {
  0 || 1 => const Color(0xffff5252),
  2 => const Color(0xffff9800),
  3 => const Color(0xffeab308),
  _ => const Color(0xff16a34a),
};

String _strengthLabel(int score) => switch (score) {
  0 => 'Not set',
  1 => 'Weak',
  2 => 'Fair',
  3 => 'Good',
  _ => 'Strong',
};

class _PinSetupSheet extends StatefulWidget {
  const _PinSetupSheet();

  @override
  State<_PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<_PinSetupSheet> {
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  void _submit() {
    if (_pin.text.length != 4) {
      setState(() => _error = 'Enter a 4-digit PIN.');
      return;
    }
    if (_pin.text != _confirmPin.text) {
      setState(() => _error = 'PIN confirmation does not match.');
      return;
    }
    Navigator.pop(context, _pin.text);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      4,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create app lock PIN',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 7),
        Text(
          'You will use this PIN whenever Broke.AI is locked.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _pin,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: settingsInputDecoration(
            context,
            label: '4-digit PIN',
            icon: Icons.pin_outlined,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPin,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: settingsInputDecoration(
            context,
            label: 'Confirm PIN',
            icon: Icons.lock_outline_rounded,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 18),
        SettingsPrimaryButton(
          label: 'Enable app lock',
          icon: Icons.lock_rounded,
          onPressed: _submit,
        ),
      ],
    ),
  );
}
