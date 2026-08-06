import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../providers/app_providers.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';
import '../widgets/common_widgets.dart';
import '../widgets/manual_transaction_sheet.dart';
import '../widgets/surface_card.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final notificationController = TextEditingController();
  XFile? image;
  bool processing = false;

  bool get hasText => notificationController.text.trim().isNotEmpty;

  @override
  void dispose() {
    notificationController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final selected = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (selected != null && mounted) setState(() => image = selected);
  }

  Future<void> _scanReceipt() async {
    if (image == null || await _blockExhaustedGuest()) return;
    setState(() => processing = true);
    try {
      final transaction = await ref
          .read(apiProvider)
          .receipt(File(image!.path));
      await _consumeAndRefreshTrial();
      ref.invalidate(dashboardProvider);
      if (mounted) {
        setState(() => image = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recorded: ${money(transaction.amount ?? 0)}'),
          ),
        );
      }
    } on GuestAiTrialLimitException {
      await _setRemainingTrials(0);
      if (mounted) await _showGuestLimit();
    } catch (_) {
      await _queueOffline('receipt', image!.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to the offline queue.')),
        );
      }
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  Future<void> _processNotification() async {
    final text = notificationController.text.trim();
    if (text.isEmpty || await _blockExhaustedGuest()) return;
    setState(() => processing = true);
    try {
      await ref.read(apiProvider).notification(text);
      await _consumeAndRefreshTrial();
      ref.invalidate(dashboardProvider);
      if (mounted) {
        notificationController.clear();
        setState(() {});
      }
    } on GuestAiTrialLimitException {
      await _setRemainingTrials(0);
      if (mounted) await _showGuestLimit();
    } catch (_) {
      await _queueOffline('notification', text);
    } finally {
      if (mounted) setState(() => processing = false);
    }
  }

  Future<void> _analyze() async {
    if (image != null) {
      await _scanReceipt();
    } else {
      await _processNotification();
    }
  }

  Future<bool> _blockExhaustedGuest() async {
    if (ref.read(sessionProvider).value?.isGuest == true &&
        ref.read(remainingAiTrialsProvider) == 0) {
      await _showGuestLimit();
      return true;
    }
    return false;
  }

  Future<void> _consumeAndRefreshTrial() async {
    if (ref.read(sessionProvider).value?.isGuest != true) return;
    final current = ref.read(remainingAiTrialsProvider);
    if (current != null) await _setRemainingTrials(current - 1);
    try {
      final count = await ref.read(apiProvider).remainingAiTrials();
      if (mounted) await _setRemainingTrials(count);
    } catch (_) {
      // Preserve the safe optimistic value until another refresh succeeds.
    }
  }

  Future<void> _setRemainingTrials(int value) async {
    final count = value.clamp(0, 2);
    ref.read(remainingAiTrialsProvider.notifier).state = count;
    await ref.read(sessionStoreProvider).updateActiveGuestTrials(count);
  }

  Future<void> _showGuestLimit() async {
    final action = await showModalBottomSheet<_GuestLimitAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _GuestLimitSheet(),
    );
    if (!mounted || action == null) return;
    if (action == _GuestLimitAction.authenticate) {
      ref.read(showAuthProvider.notifier).state = true;
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ManualTransactionSheet(),
    );
  }

  Future<void> _queueOffline(String type, String payload) async {
    final preferences = await SharedPreferences.getInstance();
    final queue = preferences.getStringList('offline_queue') ?? [];
    queue.add(
      jsonEncode({
        'type': type,
        'payload': payload,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );
    await preferences.setStringList('offline_queue', queue);
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(sessionProvider).value?.isGuest == true;
    final remaining = ref.watch(remainingAiTrialsProvider);
    final canAnalyze = !processing && (image != null || hasText);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 108),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan a receipt',
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Snap a photo, upload from gallery, or type it in for AI to extract your expenses.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (image != null)
                IconButton(
                  tooltip: 'Clear image',
                  onPressed: () => setState(() => image = null),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceRaised,
                    minimumSize: const Size.square(46),
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          if (isGuest) ...[
            const SizedBox(height: 16),
            _TrialBadge(remaining: remaining ?? 0),
          ],
          const SizedBox(height: 20),
          SurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _ScanViewport(image: image, processing: processing),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: processing
                            ? null
                            : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Camera'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(
                            color: AppColors.primaryAccent,
                            width: 1.4,
                          ),
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: processing
                            ? null
                            : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_outlined),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          backgroundColor: const Color(0xfffaf7ff),
                          side: const BorderSide(color: Color(0xffd8d1ff)),
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _AiActionButton(
                  enabled: canAnalyze,
                  processing: processing,
                  onPressed: _analyze,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Input using text',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('scan-text-input'),
                  controller: notificationController,
                  maxLines: 4,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Input the activities, e.g. ‘KFC 25.000 GoPay’",
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: AppColors.borderSubtle,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: AppColors.borderSubtle,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: AppColors.primaryAccent,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: processing ? null : _processNotification,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffffbf30),
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size(0, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Process with AI',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xffedf7ff),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xff2586f5)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI can detect merchant, amount, and payment method. Best results: use clear photos with good lighting.',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.verified_rounded,
                  color: AppColors.successMint,
                  size: 27,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanViewport extends StatelessWidget {
  const _ScanViewport({required this.image, required this.processing});
  final XFile? image;
  final bool processing;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 255,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image == null)
            CustomPaint(
              painter: _DashedFramePainter(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    AppAssets.scanReceiptIllustration,
                    width: 124,
                    height: 124,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Capture or upload a receipt',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Place your receipt inside the frame',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else ...[
            Image.file(File(image!.path), fit: BoxFit.cover),
            CustomPaint(painter: _FocusOverlayPainter()),
          ],
          if (processing)
            const ColoredBox(
              color: Color(0xa6000000),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xffffbf30)),
                    SizedBox(height: 14),
                    Text(
                      'Analyzing with AI...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _AiActionButton extends StatelessWidget {
  const _AiActionButton({
    required this.enabled,
    required this.processing,
    required this.onPressed,
  });

  final bool enabled;
  final bool processing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: enabled ? AppColors.primaryAccent : const Color(0xfff5f6f8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: enabled ? AppColors.primaryAccent : AppColors.borderSubtle,
      ),
    ),
    child: InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: enabled ? Colors.white : const Color(0xff9ca3af),
                  size: 20,
                ),
                const SizedBox(width: 7),
                Text(
                  processing ? 'Analyzing with AI...' : 'Analyze with AI',
                  style: TextStyle(
                    color: enabled ? Colors.white : const Color(0xff8b8fa0),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            if (!enabled && !processing) ...[
              const SizedBox(height: 3),
              const Text(
                'Add a receipt or type text to continue',
                style: TextStyle(color: Color(0xff9296a8), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _DashedFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(22),
    );
    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();
    final paint = Paint()
      ..color = const Color(0xff9b83ff)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 7), paint);
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FocusOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final focus = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .09,
        size.height * .12,
        size.width * .82,
        size.height * .76,
      ),
      const Radius.circular(18),
    );
    final outside = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(focus)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: .5),
    );
    canvas.drawRRect(
      focus,
      Paint()
        ..color = const Color(0xffffbf30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrialBadge extends StatelessWidget {
  const _TrialBadge({required this.remaining});
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final count = remaining.clamp(0, 2);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: count == 0 ? const Color(0xfffff1f2) : const Color(0xfff4f0ff),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              count == 0
                  ? Icons.hourglass_disabled_rounded
                  : Icons.auto_awesome_rounded,
              color: count == 0 ? AppColors.danger : AppColors.primaryAccent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              count == 0
                  ? 'No Free Scans Left'
                  : '$count Free Scan${count == 1 ? '' : 's'} Left',
              style: TextStyle(
                color: count == 0 ? AppColors.danger : AppColors.primaryAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _GuestLimitAction { authenticate, manual }

class _GuestLimitSheet extends StatelessWidget {
  const _GuestLimitSheet();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: SurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HeroIcon(icon: Icons.rocket_launch_rounded, size: 82),
          const SizedBox(height: 18),
          const Text(
            'Unlock Unlimited AI Scans!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          const Text(
            "You've used your 2 free guest trials. Create a free account or sign in to keep scanning receipts automatically.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, _GuestLimitAction.authenticate),
            icon: const Icon(Icons.login_rounded),
            label: const Text('Sign In / Register'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, _GuestLimitAction.manual),
            style: secondaryButtonStyle(),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Use Manual Input'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    ),
  );
}
