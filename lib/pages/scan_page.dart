import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      _setRemainingTrials(0);
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
      if (mounted) notificationController.clear();
    } on GuestAiTrialLimitException {
      _setRemainingTrials(0);
      if (mounted) await _showGuestLimit();
    } catch (_) {
      await _queueOffline('notification', text);
    } finally {
      if (mounted) setState(() => processing = false);
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
    if (current != null) _setRemainingTrials(current - 1);
    try {
      final count = await ref.read(apiProvider).remainingAiTrials();
      if (mounted) _setRemainingTrials(count);
    } catch (_) {
      // Preserve the safe optimistic value until another refresh succeeds.
    }
  }

  void _setRemainingTrials(int value) {
    final count = value.clamp(0, 2);
    ref.read(remainingAiTrialsProvider.notifier).state = count;
    ref.read(sessionStoreProvider).updateActiveGuestTrials(count);
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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Scan a receipt',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              if (image != null)
                RoundButton(
                  icon: Icons.close_rounded,
                  onTap: () => setState(() => image = null),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Snap a photo of your receipt or upload an image to analyze it with AI',
            style: TextStyle(color: AppColors.muted),
          ),
          if (isGuest) ...[
            const SizedBox(height: 12),
            _TrialBadge(remaining: remaining ?? 0),
          ],
          const SizedBox(height: 22),
          _ScanViewport(image: image, processing: processing),
          const SizedBox(height: 16),
          if (processing)
            const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                    style: secondaryButtonStyle(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_outlined),
                    label: const Text('Gallery'),
                    style: secondaryButtonStyle(),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: image == null || processing ? null : _scanReceipt,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 54),
            ),
            child: Text(
              processing ? 'Analyzing with AI...' : 'Analyze with AI',
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Input using text',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notificationController,
            maxLines: 3,
            decoration: appInputDecoration(
              'Input the activities, e.g. "KFC 25.000 GoPay"',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: processing ? null : _processNotification,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 52),
            ),
            child: const Text('Process with AI'),
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
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(26),
    child: AspectRatio(
      aspectRatio: .82,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: AppColors.charcoal,
            child: image == null
                ? const Center(
                    child: Icon(
                      Icons.receipt_long_outlined,
                      size: 72,
                      color: AppColors.muted,
                    ),
                  )
                : Image.file(File(image!.path), fit: BoxFit.cover),
          ),
          CustomPaint(painter: _FocusOverlayPainter()),
          if (processing)
            const ColoredBox(
              color: Color(0x99000000),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.gold),
                    SizedBox(height: 14),
                    Text('Analyzing with AI...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _FocusOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final focus = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .1,
        size.height * .17,
        size.width * .8,
        size.height * .66,
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
        ..color = AppColors.gold
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: count == 0 ? const Color(0xfffff1f2) : const Color(0xfff0fdfa),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: count == 0 ? AppColors.danger : AppColors.successMint,
          ),
        ),
        child: Text(
          count == 0
              ? 'No Free Scans Left'
              : '$count Free Scan${count == 1 ? '' : 's'} Left',
          style: TextStyle(
            color: count == 0 ? AppColors.danger : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
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
            style: TextStyle(color: AppColors.muted, height: 1.45),
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
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      ),
    ),
  );
}
