import 'package:broke_ai_app/app.dart';
import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/providers/app_providers.dart';
import 'package:broke_ai_app/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Session _guestSession() => Session(
  token: 'persistent-guest-token',
  expiresAt: DateTime.now().add(const Duration(days: 30)),
  username: 'guest_persistent',
  isGuest: true,
  remainingAiTrials: 2,
  fullName: 'Guest User',
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('guest identity and trial count survive a process restart', () async {
    final activeStore = SessionStore();
    await activeStore.save(_guestSession());
    await activeStore.updateActiveGuestTrials(1);

    expect(activeStore.guestEntryConfirmed, isTrue);

    final restartedStore = SessionStore();
    final restored = await restartedStore.read();

    expect(restored?.username, 'guest_persistent');
    expect(restored?.remainingAiTrials, 1);
    expect(restartedStore.guestEntryConfirmed, isFalse);
  });

  testWidgets(
    'cold-start guest sees welcome and Try Now reuses the stored identity',
    (tester) async {
      final firstProcess = SessionStore();
      await firstProcess.save(_guestSession());
      final restartedStore = SessionStore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionStoreProvider.overrideWithValue(restartedStore)],
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 901));
      await tester.pump();

      expect(find.text('Try Now'), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);

      await tester.tap(find.text('Try Now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(restartedStore.guestEntryConfirmed, isTrue);
      expect((await restartedStore.read())?.username, 'guest_persistent');
      expect(find.byType(AppShell), findsOneWidget);
    },
  );
}
