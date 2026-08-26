class Session {
  const Session({
    required this.token,
    required this.expiresAt,
    required this.username,
    required this.isGuest,
    this.accountId,
    this.localScopeId,
    this.clientGuestId,
    this.installationCredential,
    this.refreshAvailable = false,
    this.remainingAiTrials = 0,
    this.fullName,
    this.email,
  });

  final String token;
  final DateTime expiresAt;
  final String username;
  final bool isGuest;
  final String? accountId;
  final String? localScopeId;
  final String? clientGuestId;
  final String? installationCredential;
  final bool refreshAvailable;
  final int remainingAiTrials;
  final String? fullName;
  final String? email;

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    token: json['token'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    username: json['username'] as String,
    isGuest: json['isGuest'] as bool? ?? false,
    accountId: json['accountId'] as String?,
    localScopeId: json['localScopeId'] as String?,
    clientGuestId: json['clientGuestId'] as String?,
    installationCredential: json['installationCredential'] as String?,
    refreshAvailable: json['refresh_available'] as bool? ?? false,
    remainingAiTrials: (json['remaining_ai_trials'] as num?)?.toInt() ?? 0,
    fullName: json['fullName'] as String?,
    email: json['email'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'token': token,
    'expiresAt': expiresAt.toIso8601String(),
    'username': username,
    'isGuest': isGuest,
    'accountId': accountId,
    'localScopeId': localScopeId,
    'clientGuestId': clientGuestId,
    'installationCredential': installationCredential,
    'refresh_available': refreshAvailable,
    'remaining_ai_trials': remainingAiTrials,
    'fullName': fullName,
    'email': email,
  };

  /// Local account access is intentionally independent from API authentication.
  bool get valid => accountScope.trim().isNotEmpty;
  bool get canAuthenticate =>
      token.trim().isNotEmpty && expiresAt.isAfter(DateTime.now());
  bool get reauthenticationRequired => !canAuthenticate;
  String get accountScope => localScopeId?.trim().isNotEmpty == true
      ? localScopeId!
      : accountId?.trim().isNotEmpty == true
      ? accountId!
      : username;
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

  Session copyWith({
    String? token,
    DateTime? expiresAt,
    int? remainingAiTrials,
    bool? isGuest,
    String? accountId,
    String? localScopeId,
    String? clientGuestId,
    String? installationCredential,
    bool? refreshAvailable,
    String? username,
    String? fullName,
    String? email,
  }) => Session(
    token: token ?? this.token,
    expiresAt: expiresAt ?? this.expiresAt,
    username: username ?? this.username,
    isGuest: isGuest ?? this.isGuest,
    accountId: accountId ?? this.accountId,
    localScopeId: localScopeId ?? this.localScopeId,
    clientGuestId: clientGuestId ?? this.clientGuestId,
    installationCredential:
        installationCredential ?? this.installationCredential,
    refreshAvailable: refreshAvailable ?? this.refreshAvailable,
    remainingAiTrials: remainingAiTrials ?? this.remainingAiTrials,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
  );
}
