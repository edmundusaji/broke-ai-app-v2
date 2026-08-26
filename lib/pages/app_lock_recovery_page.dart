import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_assets.dart';
import '../providers/app_providers.dart';

class AppLockRecoveryChoicePage extends ConsumerStatefulWidget {
  const AppLockRecoveryChoicePage({super.key});

  @override
  ConsumerState<AppLockRecoveryChoicePage> createState() =>
      _AppLockRecoveryChoicePageState();
}

class _AppLockRecoveryChoicePageState
    extends ConsumerState<AppLockRecoveryChoicePage> {
  bool _disabling = false;
  String? _error;

  void _changePin() {
    ref.read(appLockRecoveryProvider.notifier).state =
        AppLockRecoveryStep.changePin;
  }

  Future<void> _later() async {
    if (_disabling) return;
    setState(() {
      _disabling = true;
      _error = null;
    });
    try {
      await ref.read(appLockServiceProvider).disable();
      ref.invalidate(appLockSettingsProvider);
      ref.read(appUnlockedProvider.notifier).state = true;
      ref.read(appLockRecoveryProvider.notifier).state =
          AppLockRecoveryStep.none;
    } catch (_) {
      if (mounted) {
        setState(() {
          _disabling = false;
          _error = 'Could not deactivate app lock. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _RecoveryScaffold(
    icon: Icons.verified_user_rounded,
    title: 'Identity verified',
    subtitle: 'Would you like to create a new app lock PIN?',
    child: Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _disabling ? null : _changePin,
            icon: const Icon(Icons.password_rounded),
            label: const Text('Change PIN'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _disabling ? null : _later,
            child: _disabling
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Later'),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Choosing Later will deactivate app lock on this device.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
  );
}

class AppLockChangePinPage extends ConsumerStatefulWidget {
  const AppLockChangePinPage({super.key});

  @override
  ConsumerState<AppLockChangePinPage> createState() =>
      _AppLockChangePinPageState();
}

class _AppLockChangePinPageState extends ConsumerState<AppLockChangePinPage> {
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_pin.text.length != 4) {
      setState(() => _error = 'Enter a 4-digit PIN.');
      return;
    }
    if (_pin.text != _confirmation.text) {
      setState(() => _error = 'PIN confirmation does not match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(appLockServiceProvider).replacePin(_pin.text);
      ref.invalidate(appLockSettingsProvider);
      ref.read(appUnlockedProvider.notifier).state = true;
      ref.read(appLockRecoveryProvider.notifier).state =
          AppLockRecoveryStep.none;
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the new PIN. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _RecoveryScaffold(
    icon: Icons.password_rounded,
    title: 'Create a new PIN',
    subtitle: 'Choose the 4-digit PIN you will use to unlock Broke.AI.',
    child: Column(
      children: [
        TextField(
          controller: _pin,
          autofocus: true,
          enabled: !_saving,
          obscureText: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: _pinFormatters,
          decoration: const InputDecoration(
            labelText: 'New PIN',
            prefixIcon: Icon(Icons.pin_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirmation,
          enabled: !_saving,
          obscureText: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: _pinFormatters,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            labelText: 'Confirm new PIN',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Save new PIN'),
          ),
        ),
      ],
    ),
  );
}

final _pinFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(4),
];

class _RecoveryScaffold extends StatelessWidget {
  const _RecoveryScaffold({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      AppAssets.appIcon,
                      width: 82,
                      height: 82,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Icon(icon, size: 64, color: colors.primary),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Icon(icon, color: colors.primary, size: 30),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
