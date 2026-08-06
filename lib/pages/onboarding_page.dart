import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../providers/app_providers.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, this.startupError});

  final String? startupError;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _controller = PageController();
  Timer? _autoAdvanceTimer;
  int _page = 0;
  bool _loading = false;
  String? _error;

  static const _slides = [
    _SlideData(
      semanticTitle: 'How would you like to start?',
      title: 'How would\nyou like to\n',
      highlight: 'start?',
      subtitle: 'Track expenses instantly,\nor explore powerful\nAI features.',
      asset: AppAssets.onboardingDog,
      cardTitle: 'Guest Mode',
      cardDescription:
          'Jump right in! Explore the app without creating an account. Includes dashboard, history, manual transactions, and 2 AI trials.',
      cardAsset: AppAssets.onboardingGuestFeature,
      fallbackIcon: Icons.rocket_launch_rounded,
      heroAlignment: Alignment(0.08, 0),
    ),
    _SlideData(
      semanticTitle: 'See your money, smarter.',
      title: 'See your\nmoney,\n',
      highlight: 'smarter.',
      subtitle:
          'Understand your\nspending with clear\ninsights and\ndetailed history.',
      asset: AppAssets.onboardingInsightsDog,
      cardTitle: 'Smarter Insights',
      cardDescription:
          'Monthly summaries, category breakdowns, and full transaction history help you see where your money goes.',
      cardAsset: AppAssets.onboardingInsightsFeature,
      fallbackIcon: Icons.analytics_rounded,
      heroAlignment: Alignment(0.04, 0),
    ),
    _SlideData(
      semanticTitle: 'Every expense. Every insight. One place.',
      title: 'Every expense.\nEvery insight.\n',
      highlight: 'One place.',
      subtitle:
          'Scan, track, and analyze\nyour spending with\nsmart summaries and\nreal-time insights.',
      asset: AppAssets.onboardingTrackingDog,
      cardTitle: 'Smart Tracking',
      cardDescription:
          'Track expenses your way: scan receipts, read notifications, or add manually in seconds. We handle the rest.',
      cardAsset: AppAssets.onboardingTrackingFeature,
      fallbackIcon: Icons.document_scanner_rounded,
      heroAlignment: Alignment(0, 0.06),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _autoAdvanceTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _showNextSlide(),
    );
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _tryNow() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await ref.read(apiProvider).guestLogin();
      await ref.read(sessionStoreProvider).save(session);
      ref.read(showAuthProvider.notifier).state = false;
      ref.invalidate(sessionProvider);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to start Guest Mode. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAuth() {
    if (_loading) return;
    ref.read(showAuthProvider.notifier).state = true;
  }

  void _showNextSlide() {
    if (!_controller.hasClients || _loading) return;
    final nextPage = (_page + 1) % _slides.length;
    _controller.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primaryBackground,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 760;
          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) => _OnboardingSlide(
                    data: _slides[index],
                    compact: compact,
                    onCardTap: index < _slides.length - 1
                        ? _showNextSlide
                        : null,
                  ),
                ),
              ),
              _CarouselControls(
                page: _page,
                loading: _loading,
                error: _error ?? widget.startupError,
                onDotTap: (index) => _controller.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                ),
                onTryNow: _tryNow,
                onAuth: _openAuth,
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.data,
    required this.compact,
    required this.onCardTap,
  });

  final _SlideData data;
  final bool compact;
  final VoidCallback? onCardTap;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(20, compact ? 8 : 14, 20, 8),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          children: [
            SizedBox(
              height: compact ? 400 : 500,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: 28,
                    right: -28,
                    top: compact ? 48 : 58,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset(
                        data.asset,
                        fit: BoxFit.contain,
                        alignment: data.heroAlignment,
                        cacheWidth: 1200,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: AppColors.surfaceCard,
                          child: Center(
                            child: Icon(
                              Icons.pets_rounded,
                              size: 72,
                              color: AppColors.primaryAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 250,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              AppColors.surfaceCard,
                              AppColors.surfaceCard.withValues(alpha: .96),
                              AppColors.surfaceCard.withValues(alpha: 0),
                            ],
                            stops: const [0, .58, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 16,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 22,
                      color: AppColors.highlightGold,
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 48,
                    child: Semantics(
                      label: data.semanticTitle,
                      excludeSemantics: true,
                      child: SizedBox(
                        width: 275,
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: compact ? 31 : 36,
                              height: 1.03,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                            children: [
                              TextSpan(text: data.title),
                              TextSpan(
                                text: data.highlight,
                                style: const TextStyle(
                                  color: AppColors.secondaryAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: compact ? 168 : 194,
                    child: Text(
                      data.subtitle,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: compact ? 13 : 15,
                        height: 1.48,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 10 : 16),
            _FeatureCard(data: data, onTap: onCardTap),
          ],
        ),
      ),
    ),
  );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.data, this.onTap});

  final _SlideData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0x405b50f6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140f172a),
              blurRadius: 22,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 82,
              height: 82,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  data.cardAsset,
                  fit: BoxFit.cover,
                  cacheWidth: 320,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: const Color(0xfff3f1ff),
                    child: Icon(
                      data.fallbackIcon,
                      size: 43,
                      color: AppColors.primaryAccent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.cardTitle,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.cardDescription,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primaryAccent,
              size: 30,
            ),
          ],
        ),
      ),
    ),
  );
}

class _CarouselControls extends StatelessWidget {
  const _CarouselControls({
    required this.page,
    required this.loading,
    required this.error,
    required this.onDotTap,
    required this.onTryNow,
    required this.onAuth,
  });

  final int page;
  final bool loading;
  final String? error;
  final ValueChanged<int> onDotTap;
  final VoidCallback onTryNow;
  final VoidCallback onAuth;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.primaryBackground,
    padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Onboarding page ${page + 1} of 3',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final selected = index == page;
                  return GestureDetector(
                    onTap: () => onDotTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: selected ? 13 : 11,
                      height: selected ? 13 : 11,
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xffffb814)
                            : const Color(0xffe6e7fb),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xffffd54f), Color(0xffffb300)],
                  ),
                  borderRadius: BorderRadius.circular(29),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40eab308),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: loading ? null : onTryNow,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: AppColors.textPrimary,
                    disabledForegroundColor: AppColors.textSecondary,
                    shadowColor: Colors.transparent,
                    shape: const StadiumBorder(),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Try Now',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 14),
                            Icon(Icons.arrow_forward_rounded),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: loading ? null : onAuth,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(
                    color: AppColors.secondaryAccent,
                    width: 1.5,
                  ),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(
                  Icons.account_circle_outlined,
                  color: AppColors.secondaryAccent,
                  size: 27,
                ),
                label: const Text(
                  'Sign In / Register',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SlideData {
  const _SlideData({
    required this.semanticTitle,
    required this.title,
    required this.highlight,
    required this.subtitle,
    required this.asset,
    required this.cardTitle,
    required this.cardDescription,
    required this.cardAsset,
    required this.fallbackIcon,
    required this.heroAlignment,
  });

  final String semanticTitle;
  final String title;
  final String highlight;
  final String subtitle;
  final String asset;
  final String cardTitle;
  final String cardDescription;
  final String cardAsset;
  final IconData fallbackIcon;
  final Alignment heroAlignment;
}
