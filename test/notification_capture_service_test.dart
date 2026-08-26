import 'package:broke_ai_app/services/notification_capture_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('broke.ai/notification_capture');
  final calls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getStatus') {
            return <String, Object?>{
              'supported': true,
              'enabled': true,
              'accessGranted': true,
              'consentAccepted': true,
              'selectedSources': ['com.gojek.app'],
              'supportedSources': [
                {'packageName': 'com.gojek.app', 'name': 'Gojek / GoPay'},
              ],
              'queueCount': 2,
              'needsReconnect': false,
              'deviceId': 'device-id',
              'lastSuccessAt': 1777000000000,
              'lastResult': 'SAVED',
            };
          }
          return null;
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps native capture state', () async {
    final status = await NotificationCaptureService(channel: channel).status();

    expect(status.active, isTrue);
    expect(status.queueCount, 2);
    expect(status.deviceId, 'device-id');
    expect(status.selectedSources, {'com.gojek.app'});
    expect(status.sources.single.name, 'Gojek / GoPay');
  });

  test('sends the provisioned background configuration to Android', () async {
    final service = NotificationCaptureService(channel: channel);

    await service.configure(
      baseUrl: 'https://example.test/api/v1/',
      credential: 'bcap_secret',
      deviceId: 'device-id',
      selectedSources: {'com.gojek.app', 'ovo.id'},
    );

    expect(calls.single.method, 'configure');
    expect(calls.single.arguments, {
      'enabled': true,
      'baseUrl': 'https://example.test/api/v1/',
      'credential': 'bcap_secret',
      'deviceId': 'device-id',
      'selectedSources': containsAll(['com.gojek.app', 'ovo.id']),
    });
  });

  test('is unavailable on non-Android platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final status = await NotificationCaptureService(channel: channel).status();

    expect(status.supported, isFalse);
    expect(calls, isEmpty);
  });
}
