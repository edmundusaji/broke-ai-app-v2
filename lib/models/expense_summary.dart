class CategorySummary {
  const CategorySummary(this.category, this.totalAmount);

  final String category;
  final double totalAmount;

  factory CategorySummary.fromJson(Map<String, dynamic> json) =>
      CategorySummary(
        json['category'] as String? ?? 'Other',
        (json['totalAmount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'category': category,
    'totalAmount': totalAmount,
  };
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
