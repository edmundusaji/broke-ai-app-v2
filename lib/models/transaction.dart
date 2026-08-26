class Transaction {
  const Transaction({
    this.id,
    this.clientTransactionId,
    this.date,
    this.amount,
    this.category,
    this.paymentMethod,
    this.description,
    this.inputType,
    this.validationStatus,
    this.captureId,
    this.captureMode,
    this.sourcePackage,
    this.sourceNotificationPostedAt,
    this.revision,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncState = 'synced',
    this.syncErrorCode,
  });

  final int? id;
  final String? clientTransactionId;
  final String? date;
  final double? amount;
  final String? category;
  final String? paymentMethod;
  final String? description;
  final String? inputType;
  final String? validationStatus;
  final String? captureId;
  final String? captureMode;
  final String? sourcePackage;
  final String? sourceNotificationPostedAt;
  final int? revision;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final String syncState;
  final String? syncErrorCode;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: (json['id'] as num?)?.toInt(),
    clientTransactionId: json['clientTransactionId'] as String?,
    date: json['date'] as String?,
    amount: (json['amount'] as num?)?.toDouble(),
    category: json['category'] as String?,
    paymentMethod: json['paymentMethod'] as String?,
    description: json['description'] as String?,
    inputType: json['inputType'] as String?,
    validationStatus: json['validationStatus'] as String?,
    captureId: json['captureId'] as String?,
    captureMode: json['captureMode'] as String?,
    sourcePackage: json['sourcePackage'] as String?,
    sourceNotificationPostedAt: json['sourceNotificationPostedAt'] as String?,
    revision: (json['revision'] as num?)?.toInt(),
    createdAt: json['createdAt'] as String?,
    updatedAt: json['updatedAt'] as String?,
    deletedAt: json['deletedAt'] as String?,
    syncState: json['syncState'] as String? ?? 'synced',
    syncErrorCode: json['syncErrorCode'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientTransactionId': clientTransactionId,
    'date': date,
    'amount': amount,
    'category': category,
    'paymentMethod': paymentMethod,
    'description': description,
    'inputType': inputType,
    'validationStatus': validationStatus,
    'captureId': captureId,
    'captureMode': captureMode,
    'sourcePackage': sourcePackage,
    'sourceNotificationPostedAt': sourceNotificationPostedAt,
    'revision': revision,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'deletedAt': deletedAt,
    'syncState': syncState,
    'syncErrorCode': syncErrorCode,
  };

  Transaction copyWith({
    int? id,
    String? clientTransactionId,
    String? date,
    double? amount,
    String? category,
    String? paymentMethod,
    String? description,
    String? inputType,
    String? validationStatus,
    String? captureId,
    String? captureMode,
    String? sourcePackage,
    String? sourceNotificationPostedAt,
    int? revision,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    String? syncState,
    String? syncErrorCode,
  }) => Transaction(
    id: id ?? this.id,
    clientTransactionId: clientTransactionId ?? this.clientTransactionId,
    date: date ?? this.date,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    description: description ?? this.description,
    inputType: inputType ?? this.inputType,
    validationStatus: validationStatus ?? this.validationStatus,
    captureId: captureId ?? this.captureId,
    captureMode: captureMode ?? this.captureMode,
    sourcePackage: sourcePackage ?? this.sourcePackage,
    sourceNotificationPostedAt:
        sourceNotificationPostedAt ?? this.sourceNotificationPostedAt,
    revision: revision ?? this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
    syncState: syncState ?? this.syncState,
    syncErrorCode: syncErrorCode ?? this.syncErrorCode,
  );
}
