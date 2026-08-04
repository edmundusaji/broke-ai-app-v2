class Transaction {
  const Transaction({
    this.id,
    this.tanggal,
    this.jumlah,
    this.kategori,
    this.paymentMethod,
    this.description,
    this.tipeInput,
  });

  final int? id;
  final String? tanggal;
  final double? jumlah;
  final String? kategori;
  final String? paymentMethod;
  final String? description;
  final String? tipeInput;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: (json['id'] as num?)?.toInt(),
    tanggal: json['tanggal'] as String?,
    jumlah: (json['jumlah'] as num?)?.toDouble(),
    kategori: json['kategori'] as String?,
    paymentMethod: json['paymentMethod'] as String?,
    description: json['description'] as String?,
    tipeInput: json['tipeInput'] as String?,
  );
}
