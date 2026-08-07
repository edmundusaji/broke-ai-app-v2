import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';

class ExpenseWorkbook {
  const ExpenseWorkbook({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

class ExpenseExportService {
  const ExpenseExportService();

  static const _xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  ExpenseWorkbook createMonthlyWorkbook({
    required List<Transaction> transactions,
    required DateTime month,
  }) {
    final excel = Excel.createExcel();
    const sheetName = 'Expenses';
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.rename(defaultSheet, sheetName);
    }
    final sheet = excel[sheetName];
    final period = DateFormat('MMMM yyyy', 'en_US').format(month);
    final total = transactions.fold<double>(
      0,
      (sum, transaction) => sum + (transaction.amount ?? 0),
    );

    sheet.appendRow([TextCellValue('Broke.AI Monthly Expense Report')]);
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('G1'));
    sheet.appendRow([
      TextCellValue('Period'),
      TextCellValue(period),
      null,
      TextCellValue('Transactions'),
      IntCellValue(transactions.length),
    ]);
    sheet.appendRow([TextCellValue('Total amount'), DoubleCellValue(total)]);
    sheet.appendRow(const [null]);
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Category'),
      TextCellValue('Description'),
      TextCellValue('Payment Method'),
      TextCellValue('Input Type'),
      TextCellValue('Validation Status'),
      TextCellValue('Amount (IDR)'),
    ]);

    for (final transaction in transactions) {
      final parsedDate = DateTime.tryParse(transaction.date ?? '');
      sheet.appendRow([
        parsedDate == null
            ? TextCellValue(transaction.date ?? '')
            : DateCellValue.fromDateTime(parsedDate),
        TextCellValue(transaction.category ?? 'Other'),
        TextCellValue(transaction.description ?? ''),
        TextCellValue(transaction.paymentMethod ?? ''),
        TextCellValue(transaction.inputType ?? ''),
        TextCellValue(transaction.validationStatus ?? ''),
        DoubleCellValue(transaction.amount ?? 0),
      ]);
    }

    _applyStyles(sheet, transactions.length);
    final encoded = excel.save();
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Unable to create the Excel workbook.');
    }

    return ExpenseWorkbook(
      bytes: Uint8List.fromList(encoded),
      fileName:
          'broke_ai_expenses_${month.year}_${month.month.toString().padLeft(2, '0')}.xlsx',
    );
  }

  Future<ShareResult> exportMonthly({
    required List<Transaction> transactions,
    required DateTime month,
  }) async {
    final workbook = createMonthlyWorkbook(
      transactions: transactions,
      month: month,
    );
    final period = DateFormat('MMMM yyyy', 'en_US').format(month);
    return SharePlus.instance.share(
      ShareParams(
        title: 'Export expense report',
        subject: 'Broke.AI expense report - $period',
        text: 'Broke.AI monthly expense report for $period.',
        files: [XFile.fromData(workbook.bytes, mimeType: _xlsxMimeType)],
        fileNameOverrides: [workbook.fileName],
      ),
    );
  }

  void _applyStyles(Sheet sheet, int transactionCount) {
    final purple = ExcelColor.fromHexString('#5B50F6');
    final blue = ExcelColor.fromHexString('#2563EB');
    final white = ExcelColor.fromHexString('#FFFFFF');
    final slate = ExcelColor.fromHexString('#0F172A');
    final border = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString('#E2E8F0'),
    );

    sheet.setRowHeight(0, 30);
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      backgroundColorHex: purple,
      fontColorHex: white,
      bold: true,
      fontSize: 16,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (final address in ['A2', 'D2', 'A3']) {
      sheet.cell(CellIndex.indexByString(address)).cellStyle = CellStyle(
        bold: true,
        fontColorHex: purple,
      );
    }
    sheet.cell(CellIndex.indexByString('B3')).cellStyle = CellStyle(
      bold: true,
      fontColorHex: slate,
      numberFormat: CustomNumericNumFormat(formatCode: '"Rp" #,##0'),
    );

    for (var column = 0; column < 7; column++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 4))
          .cellStyle = CellStyle(
        backgroundColorHex: blue,
        fontColorHex: white,
        bold: true,
        verticalAlign: VerticalAlign.Center,
        bottomBorder: border,
      );
    }
    sheet.setRowHeight(4, 24);

    for (var row = 5; row < transactionCount + 5; row++) {
      final dateCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      );
      if (dateCell.value is DateCellValue) {
        dateCell.cellStyle = CellStyle(
          numberFormat: CustomDateTimeNumFormat(formatCode: 'yyyy-mm-dd'),
          bottomBorder: border,
        );
      } else {
        dateCell.cellStyle = CellStyle(bottomBorder: border);
      }

      for (var column = 1; column < 6; column++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
            )
            .cellStyle = CellStyle(
          bottomBorder: border,
        );
      }
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          .cellStyle = CellStyle(
        numberFormat: CustomNumericNumFormat(formatCode: '"Rp" #,##0'),
        horizontalAlign: HorizontalAlign.Right,
        bottomBorder: border,
      );
    }

    const widths = [14.0, 18.0, 34.0, 22.0, 16.0, 20.0, 18.0];
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }
  }
}
