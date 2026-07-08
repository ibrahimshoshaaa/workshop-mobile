import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/expense_model.dart';

/// خدمة توليد ملف Excel يحتوي شيتين: الطلبات والمصروفات
class ExcelExportService {
  ExcelExportService._();
  static final ExcelExportService instance = ExcelExportService._();

  Uint8List buildFinancialWorkbook({
    required List<OrderModel> orders,
    required List<ExpenseModel> expenses,
  }) {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.getDefaultSheet()!;

    // ---- شيت الطلبات ----
    final ordersSheet = excel['الطلبات'];
    ordersSheet.appendRow([
      TextCellValue('العميل'),
      TextCellValue('الصنف'),
      TextCellValue('الحالة'),
      TextCellValue('الإجمالي'),
      TextCellValue('المدفوع'),
      TextCellValue('المتبقي'),
      TextCellValue('تاريخ التسليم'),
    ]);
    for (final o in orders) {
      ordersSheet.appendRow([
        TextCellValue(o.customerName),
        TextCellValue(o.itemType),
        TextCellValue(o.status),
        DoubleCellValue(o.totalAmount),
        DoubleCellValue(o.totalPaid),
        DoubleCellValue(o.remainingAmount),
        TextCellValue(DateFormat('d/M/yyyy').format(o.deliveryDate)),
      ]);
    }

    // ---- شيت المصروفات ----
    final expensesSheet = excel['المصروفات'];
    expensesSheet.appendRow([
      TextCellValue('الفئة'),
      TextCellValue('الوصف'),
      TextCellValue('اسم الصنايعي'),
      TextCellValue('المبلغ'),
      TextCellValue('التاريخ'),
    ]);
    for (final e in expenses) {
      expensesSheet.appendRow([
        TextCellValue(e.category),
        TextCellValue(e.description),
        TextCellValue(e.workerName ?? ''),
        DoubleCellValue(e.amount),
        TextCellValue(DateFormat('d/M/yyyy').format(e.date)),
      ]);
    }

    // حذف الشيت الافتراضي الفاضي
    excel.delete(defaultSheetName);

    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }
}
