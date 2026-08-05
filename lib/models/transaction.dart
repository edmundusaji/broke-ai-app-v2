class Transaction {
  const Transaction({
    this.id,
    this.date,
    this.amount,
    this.category,
    this.paymentMethod,
    this.description,
    this.inputType,
    this.validationStatus,
  });

  final int? id;
  final String? date;
  final double? amount;
  final String? category;
  final String? paymentMethod;
  final String? description;
  final String? inputType;
  final String? validationStatus;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: (json['id'] as num?)?.toInt(),
    date: json['date'] as String?,
    amount: (json['amount'] as num?)?.toDouble(),
    category: json['category'] as String?,
    paymentMethod: json['paymentMethod'] as String?,
    description: json['description'] as String?,
    inputType: json['inputType'] as String?,
    validationStatus: json['validationStatus'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'amount': amount,
    'category': category,
    'paymentMethod': paymentMethod,
    'description': description,
    'inputType': inputType,
    'validationStatus': validationStatus,
  };
}
