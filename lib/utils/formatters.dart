import 'package:intl/intl.dart';

String money(double amount) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
).format(amount);

String shortDate(String? value) {
  try {
    return DateFormat('d MMM', 'id_ID').format(DateTime.parse(value!));
  } catch (_) {
    return '-';
  }
}

bool isToday(String? value) {
  try {
    final date = DateTime.parse(value!);
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  } catch (_) {
    return false;
  }
}
