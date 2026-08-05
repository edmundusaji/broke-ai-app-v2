import 'package:broke_ai_app/models/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guest session exposes guest identity and display name', () {
    final session = Session(
      token: 'guest-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      username: 'guest_123',
      isGuest: true,
      remainingAiTrials: 2,
      fullName: 'Guest User',
    );

    expect(session.valid, isTrue);
    expect(session.isGuest, isTrue);
    expect(session.remainingAiTrials, 2);
    expect(session.displayName, 'Guest User');
    expect(session.initials, 'GU');
    expect(session.toJson()['fullName'], 'Guest User');
  });

  test('registered session remains distinguishable from guest session', () {
    final session = Session(
      token: 'user-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      username: 'edmund',
      isGuest: false,
      fullName: 'Edmund Aji',
      email: 'edmund@example.com',
    );

    expect(session.isGuest, isFalse);
    expect(session.email, 'edmund@example.com');
    expect(session.initials, 'EA');
  });

  test('stored session deserializes fullName using the English key', () {
    final session = Session.fromJson({
      'token': 'stored-token',
      'expiresAt': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      'username': 'edmund',
      'isGuest': false,
      'remaining_ai_trials': 0,
      'fullName': 'Edmund Aji',
      'email': 'edmund@example.com',
    });

    expect(session.fullName, 'Edmund Aji');
    expect(session.displayName, 'Edmund Aji');
  });
}
