import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_assets.dart';
import '../providers/app_providers.dart';

class AppLockPage extends ConsumerStatefulWidget {
  const AppLockPage({super.key});

  @override
  ConsumerState<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends ConsumerState<AppLockPage> {
  final _pin = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_checking || _pin.text.length != 4) {
      setState(() => _error = 'Enter your 4-digit PIN.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    final valid = await ref.read(appLockServiceProvider).verifyPin(_pin.text);
    if (!mounted) return;
    if (valid) {
      ref.read(appUnlockedProvider.notifier).state = true;
      return;
    }
    _pin.clear();
    setState(() {
      _checking = false;
      _error = 'That PIN is incorrect. Try again.';
    });
  }

  void _forgotPin() {
    ref.read(appLockRecoveryProvider.notifier).state =
        AppLockRecoveryStep.reauthenticate;
    ref.read(showAuthProvider.notifier).state = true;
  }

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
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      AppAssets.appIcon,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.lock_rounded,
                        size: 68,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Unlock Broke.AI',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your app lock PIN to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _pin,
                    autofocus: true,
                    enabled: !_checking,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 12,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onSubmitted: (_) => _unlock(),
                    decoration: InputDecoration(
                      labelText: '4-digit PIN',
                      errorText: _error,
                      prefixIcon: const Icon(Icons.pin_outlined),
                      // Match the prefix width so the editable area and PIN
                      // dots are centered against the full-width button.
                      suffixIcon: const SizedBox(width: 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _checking ? null : _forgotPin,
                      child: const Text('Forgot PIN?'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _checking ? null : _unlock,
                      icon: _checking
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open_rounded),
                      label: const Text('Unlock'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
