import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../providers/app_providers.dart';
import '../widgets/common_widgets.dart';
import '../widgets/gradient_action_button.dart';
import '../widgets/mascot_image.dart';

class AccountOptionPage extends ConsumerStatefulWidget {
  const AccountOptionPage({super.key, this.startupError});

  final String? startupError;

  @override
  ConsumerState<AccountOptionPage> createState() => _AccountOptionPageState();
}

class _AccountOptionPageState extends ConsumerState<AccountOptionPage> {
  bool loading = false;
  String? error;

  Future<void> _tryNow() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final session = await ref.read(apiProvider).guestLogin();
      await ref.read(sessionStoreProvider).save(session);
      ref.read(showAuthProvider.notifier).state = false;
      ref.invalidate(sessionProvider);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to start Guest Mode. Please try again.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primaryBackground,
    body: ColoredBox(
      color: AppColors.primaryBackground,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandMark(),
                    const SizedBox(height: 20),
                    const Text(
                      'How would you like to start?',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 34,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.9,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Track expenses instantly, or sign in to unlock every AI feature.',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.45,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const MascotImage(
                      asset: AppAssets.onboardingDog,
                      height: 252,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                    const SizedBox(height: 18),
                    const _GuestModeCard(),
                    if ((error ?? widget.startupError) != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        (error ?? widget.startupError)!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.coral),
                      ),
                    ],
                    const SizedBox(height: 18),
                    GradientActionButton(
                      label: loading ? 'Starting Guest Mode...' : 'Try Now',
                      onPressed: loading ? null : _tryNow,
                      icon: Icons.arrow_forward_rounded,
                      loading: loading,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: loading
                          ? null
                          : () => ref.read(showAuthProvider.notifier).state =
                                true,
                      style: secondaryButtonStyle().copyWith(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.person_outline_rounded),
                      label: const Text(
                        'Sign In / Register',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _GuestModeCard extends StatelessWidget {
  const _GuestModeCard();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.borderSubtle),
      boxShadow: const [
        BoxShadow(
          color: Color(0x140f172a),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    padding: const EdgeInsets.all(18),
    child: const Row(
      children: [
        _GuestIcon(),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Guest Mode',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Explore the dashboard, history, manual transactions, and 2 AI trials.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, color: AppColors.secondaryAccent),
      ],
    ),
  );
}

class _GuestIcon extends StatelessWidget {
  const _GuestIcon();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color(0x145b50f6),
      shape: BoxShape.circle,
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Icon(Icons.rocket_launch_rounded, color: AppColors.primaryAccent),
    ),
  );
}
