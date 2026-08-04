class Transaction {
  const Transaction({
    this.id,
    this.tanggal,
    this.jumlah,
    this.kategori,
    this.merchant,
    this.tipeInput,
  });

  final int? id;
  final String? tanggal;
  final double? jumlah;
  final String? kategori;
  final String? merchant;
  final String? tipeInput;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: (json['id'] as num?)?.toInt(),
    tanggal: json['tanggal'] as String?,
    jumlah: (json['jumlah'] as num?)?.toDouble(),
    kategori: json['kategori'] as String?,
    merchant: json['merchant'] as String?,
    tipeInput: json['tipeInput'] as String?,
  );
}
