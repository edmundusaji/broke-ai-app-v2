import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationCaptureSource {
  const NotificationCaptureSource({
    required this.packageName,
    required this.name,
  });

  final String packageName;
  final String name;

  factory NotificationCaptureSource.fromJson(Map<dynamic, dynamic> json) =>
      NotificationCaptureSource(
        packageName: json['packageName'] as String,
        name: json['name'] as String,
      );
}

class NotificationCaptureStatus {
  const NotificationCaptureStatus({
    required this.supported,
    required this.enabled,
    required this.accessGranted,
    required this.consentAccepted,
    required this.selectedSources,
    required this.sources,
    required this.queueCount,
    required this.needsReconnect,
    this.deviceId,
    this.lastSuccessAt,
    this.lastResult,
    this.lastError,
  });

  const NotificationCaptureStatus.unsupported()
    : supported = false,
      enabled = false,
      accessGranted = false,
      consentAccepted = false,
      selectedSources = const {},
      sources = const [],
      queueCount = 0,
      needsReconnect = false,
      deviceId = null,
      lastSuccessAt = null,
      lastResult = null,
      lastError = null;

  final bool supported;
  final bool enabled;
  final bool accessGranted;
  final bool consentAccepted;
  final Set<String> selectedSources;
  final List<NotificationCaptureSource> sources;
  final int queueCount;
  final bool needsReconnect;
  final String? deviceId;
  final DateTime? lastSuccessAt;
  final String? lastResult;
  final String? lastError;

  bool get active => supported && enabled && accessGranted && !needsReconnect;

  factory NotificationCaptureStatus.fromJson(Map<dynamic, dynamic> json) {
    final lastSuccessMillis = (json['lastSuccessAt'] as num?)?.toInt();
    return NotificationCaptureStatus(
      supported: json['supported'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? false,
      accessGranted: json['accessGranted'] as bool? ?? false,
      consentAccepted: json['consentAccepted'] as bool? ?? false,
      selectedSources: Set<String>.from(
        json['selectedSources'] as List<dynamic>? ?? const [],
      ),
      sources: (json['supportedSources'] as List<dynamic>? ?? const [])
          .map(
            (value) => NotificationCaptureSource.fromJson(
              value as Map<dynamic, dynamic>,
            ),
          )
          .toList(),
      queueCount: (json['queueCount'] as num?)?.toInt() ?? 0,
      needsReconnect: json['needsReconnect'] as bool? ?? false,
      deviceId: json['deviceId'] as String?,
      lastSuccessAt: lastSuccessMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastSuccessMillis),
      lastResult: json['lastResult'] as String?,
      lastError: json['lastError'] as String?,
    );
  }
}

class NotificationCaptureService {
  NotificationCaptureService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'broke.ai/notification_capture';
  final MethodChannel _channel;

  bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<NotificationCaptureStatus> status() async {
    if (!isSupportedPlatform) {
      return const NotificationCaptureStatus.unsupported();
    }
    try {
      final value = await _channel
          .invokeMapMethod<dynamic, dynamic>('getStatus')
          .timeout(const Duration(seconds: 2));
      return NotificationCaptureStatus.fromJson(value ?? const {});
    } on MissingPluginException {
      return const NotificationCaptureStatus.unsupported();
    } on TimeoutException {
      return const NotificationCaptureStatus.unsupported();
    }
  }

  Future<void> setConsent(bool accepted) async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod<void>('setConsent', {'accepted': accepted});
  }

  Future<void> openSettings() async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod<void>('openSettings');
  }

  Future<void> configure({
    required String baseUrl,
    required String credential,
    required String deviceId,
    required Set<String> selectedSources,
  }) async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod<void>('configure', {
      'enabled': true,
      'baseUrl': baseUrl,
      'credential': credential,
      'deviceId': deviceId,
      'selectedSources': selectedSources.toList(),
    });
  }

  Future<void> updateSources(Set<String> selectedSources) async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod<void>('updateSources', {
      'selectedSources': selectedSources.toList(),
    });
  }

  Future<void> retryPending() async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod<void>('retryPending');
  }

  Future<void> clear({bool clearConsent = false}) async {
    if (!isSupportedPlatform) return;
    await _channel.invokeMethod<void>('clear', {'clearConsent': clearConsent});
  }
}
