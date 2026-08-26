import 'transaction.dart';

enum TransactionMutationType { create, update, delete }

class TransactionMutation {
  const TransactionMutation({
    required this.operationId,
    required this.type,
    required this.clientTransactionId,
    required this.baseRevision,
    this.transaction,
  });

  final String operationId;
  final TransactionMutationType type;
  final String clientTransactionId;
  final int? baseRevision;
  final Transaction? transaction;

  Map<String, dynamic> toJson() => {
    'operationId': operationId,
    'type': type.name.toUpperCase(),
    'clientTransactionId': clientTransactionId,
    'baseRevision': baseRevision,
    'transaction': type == TransactionMutationType.delete
        ? null
        : {
            'date': transaction?.date?.split('T').first,
            'amount': transaction?.amount,
            'category': transaction?.category,
            'paymentMethod': transaction?.paymentMethod,
            'description': transaction?.description,
          },
  };
}

class SyncOperationResult {
  const SyncOperationResult({
    required this.operationId,
    required this.status,
    this.errorCode,
    this.message,
    this.transaction,
  });

  final String operationId;
  final String status;
  final String? errorCode;
  final String? message;
  final Transaction? transaction;

  factory SyncOperationResult.fromJson(Map<String, dynamic> json) =>
      SyncOperationResult(
        operationId: json['operationId'] as String,
        status: json['status'] as String,
        errorCode: json['errorCode'] as String?,
        message: json['message'] as String?,
        transaction: json['transaction'] is Map<String, dynamic>
            ? Transaction.fromJson(json['transaction'] as Map<String, dynamic>)
            : null,
      );
}

class SyncPushResponse {
  const SyncPushResponse({required this.results, required this.serverRevision});

  final List<SyncOperationResult> results;
  final int serverRevision;

  factory SyncPushResponse.fromJson(Map<String, dynamic> json) =>
      SyncPushResponse(
        results: (json['results'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  SyncOperationResult.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        serverRevision: (json['serverRevision'] as num?)?.toInt() ?? 0,
      );
}

class SyncPullChange {
  const SyncPullChange({
    required this.sequence,
    required this.type,
    required this.clientTransactionId,
    required this.revision,
    this.transaction,
    this.deletedAt,
  });

  final int sequence;
  final String type;
  final String clientTransactionId;
  final int revision;
  final Transaction? transaction;
  final String? deletedAt;

  factory SyncPullChange.fromJson(Map<String, dynamic> json) => SyncPullChange(
    sequence: (json['sequence'] as num).toInt(),
    type: json['type'] as String,
    clientTransactionId: json['clientTransactionId'] as String,
    revision: (json['revision'] as num).toInt(),
    transaction: json['transaction'] is Map<String, dynamic>
        ? Transaction.fromJson(json['transaction'] as Map<String, dynamic>)
        : null,
    deletedAt: json['deletedAt'] as String?,
  );
}

class SyncPullResponse {
  const SyncPullResponse({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
    required this.serverRevision,
  });

  final List<SyncPullChange> changes;
  final String nextCursor;
  final bool hasMore;
  final int serverRevision;

  factory SyncPullResponse.fromJson(Map<String, dynamic> json) =>
      SyncPullResponse(
        changes: (json['changes'] as List<dynamic>? ?? const [])
            .map(
              (item) => SyncPullChange.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        nextCursor: json['nextCursor'] as String? ?? '',
        hasMore: json['hasMore'] as bool? ?? false,
        serverRevision: (json['serverRevision'] as num?)?.toInt() ?? 0,
      );
}
