class Session {
  const Session({
    required this.token,
    required this.expiresAt,
    required this.username,
    required this.isGuest,
    this.remainingAiTrials = 0,
    this.name,
    this.email,
  });

  final String token;
  final DateTime expiresAt;
  final String username;
  final bool isGuest;
  final int remainingAiTrials;
  final String? name;
  final String? email;

  bool get valid =>
      token.trim().isNotEmpty && expiresAt.isAfter(DateTime.now());
  String get displayName => (name?.isNotEmpty ?? false) ? name! : username;
  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    final value = parts.first;
    return value
        .substring(0, value.length < 2 ? value.length : 2)
        .toUpperCase();
  }

  Session copyWith({int? remainingAiTrials, bool? isGuest}) => Session(
    token: token,
    expiresAt: expiresAt,
    username: username,
    isGuest: isGuest ?? this.isGuest,
    remainingAiTrials: remainingAiTrials ?? this.remainingAiTrials,
    name: name,
    email: email,
  );
}
