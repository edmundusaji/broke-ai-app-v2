class CategorySummary {
  const CategorySummary(this.name, this.total);

  final String name;
  final double total;

  factory CategorySummary.fromJson(Map<String, dynamic> json) =>
      CategorySummary(
        json['kategori'] as String? ?? 'Other',
        (json['totalAmount'] as num?)?.toDouble() ?? 0,
      );
}

class ExpenseSummary {
  const ExpenseSummary(this.total, this.categories);

  final double total;
  final List<CategorySummary> categories;

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) => ExpenseSummary(
    (json['totalExpense'] as num?)?.toDouble() ?? 0,
    ((json['categoryBreakdown'] as List?) ?? const [])
        .map((item) => CategorySummary.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}
