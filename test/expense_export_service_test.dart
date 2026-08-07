import 'package:broke_ai_app/models/transaction.dart';
import 'package:broke_ai_app/services/expense_export_service.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en_US'));

  test('creates a readable monthly XLSX with typed dates and amounts', () {
    const transactions = [
      Transaction(
        id: 1,
        date: '2026-08-07',
        amount: 30000,
        category: 'Transport',
        paymentMethod: 'GoPay',
        description: 'Ride home',
        inputType: 'MANUAL',
        validationStatus: 'VALID',
      ),
    ];

    final exported = const ExpenseExportService().createMonthlyWorkbook(
      transactions: transactions,
      month: DateTime(2026, 8),
    );
    final workbook = Excel.decodeBytes(exported.bytes);
    final sheet = workbook.tables['Expenses'];

    expect(exported.fileName, 'broke_ai_expenses_2026_08.xlsx');
    expect(sheet, isNotNull);
    expect(
      sheet!.cell(CellIndex.indexByString('A1')).value.toString(),
      'Broke.AI Monthly Expense Report',
    );
    expect(
      sheet.cell(CellIndex.indexByString('B2')).value.toString(),
      'August 2026',
    );
    expect(
      sheet.cell(CellIndex.indexByString('A6')).value,
      isA<DateCellValue>(),
    );
    expect(
      sheet.cell(CellIndex.indexByString('B6')).value.toString(),
      'Transport',
    );
    expect(sheet.cell(CellIndex.indexByString('D6')).value.toString(), 'GoPay');
    expect(sheet.cell(CellIndex.indexByString('G6')).value.toString(), '30000');
  });
}
