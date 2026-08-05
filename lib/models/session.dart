class Session {
  const Session({
    required this.token,
    required this.expiresAt,
    required this.username,
    required this.isGuest,
    this.remainingAiTrials = 0,
    this.fullName,
    this.email,
  });

  final String token;
  final DateTime expiresAt;
  final String username;
  final bool isGuest;
  final int remainingAiTrials;
  final String? fullName;
  final String? email;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    token: json['token'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    username: json['username'] as String,
    isGuest: json['isGuest'] as bool? ?? false,
    remainingAiTrials: (json['remaining_ai_trials'] as num?)?.toInt() ?? 0,
    fullName: json['fullName'] as String?,
    email: json['email'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'token': token,
    'expiresAt': expiresAt.toIso8601String(),
    'username': username,
    'isGuest': isGuest,
    'remaining_ai_trials': remainingAiTrials,
    'fullName': fullName,
    'email': email,
  };

  bool get valid =>
      token.trim().isNotEmpty && expiresAt.isAfter(DateTime.now());
  String get displayName =>
      (fullName?.isNotEmpty ?? false) ? fullName! : username;
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
    fullName: fullName,
    email: email,
  );
}
