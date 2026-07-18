import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/expense_model.dart';
import '../core/constants/app_constants.dart';

/// خدمة توليد ملفات PDF - فاتورة عميل، تقرير مالي شامل، وإيصال دفعة سريع
/// تستخدم خط Cairo عشان العربي يظهر صح جوه الـ PDF
class PdfExportService {
  PdfExportService._();
  static final PdfExportService instance = PdfExportService._();

  pw.Font? _arabicFont;
  pw.Font? _arabicFontBold;

  Future<void> _ensureFontsLoaded() async {
    _arabicFont ??= await PdfGoogleFonts.cairoRegular();
    _arabicFontBold ??= await PdfGoogleFonts.cairoBold();
  }

  final _currency = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 0);

  /// فاتورة عميل واحد - كل طلباته وحالتها المالية
  Future<Uint8List> buildCustomerInvoice({
    required CustomerModel customer,
    required List<OrderModel> orders,
  }) async {
    await _ensureFontsLoaded();
    final doc = pw.Document();
    final totalAmount = orders.fold<double>(0, (s, o) => s + o.totalAmount);
    final totalPaid = orders.fold<double>(0, (s, o) => s + o.totalPaid);
    final totalRemaining = orders.fold<double>(0, (s, o) => s + o.remainingAmount);

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: _arabicFont, bold: _arabicFontBold),
        build: (context) => [
          pw.Text('فاتورة عميل', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Tahoun Royal Home', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.Divider(height: 24),
          pw.Text('اسم العميل: ${customer.name}', style: const pw.TextStyle(fontSize: 14)),
          pw.Text('رقم الهاتف: ${customer.phone}', style: const pw.TextStyle(fontSize: 14)),
          if (customer.address.isNotEmpty) pw.Text('العنوان: ${customer.address}', style: const pw.TextStyle(fontSize: 14)),
          pw.Text('تاريخ الإصدار: ${DateFormat('d/M/yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.brown700),
            cellAlignment: pw.Alignment.centerRight,
            headers: ['الصنف', 'الحالة', 'الإجمالي', 'المدفوع', 'المتبقي'],
            data: orders
                .map((o) => [
                      o.itemType,
                      o.status,
                      _currency.format(o.totalAmount),
                      _currency.format(o.totalPaid),
                      _currency.format(o.remainingAmount),
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('إجمالي الاتفاق: ${_currency.format(totalAmount)}'),
                pw.SizedBox(height: 4),
                pw.Text('إجمالي المدفوع: ${_currency.format(totalPaid)}'),
                pw.SizedBox(height: 4),
                pw.Text('إجمالي المتبقي: ${_currency.format(totalRemaining)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: totalRemaining > 0 ? PdfColors.red700 : PdfColors.green700)),
              ],
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// تقرير مالي شامل - كل الطلبات والمصروفات خلال فترة معينة
  Future<Uint8List> buildFinancialReport({
    required List<OrderModel> orders,
    required List<ExpenseModel> expenses,
    required DateTime from,
    required DateTime to,
  }) async {
    await _ensureFontsLoaded();
    final doc = pw.Document();

    final totalRevenue = orders.fold<double>(0, (s, o) => s + o.totalPaid);
    final totalDebts = orders.fold<double>(0, (s, o) => s + o.remainingAmount);
    final totalExpenses = expenses.fold<double>(0, (s, e) => s + e.amount);
    final netProfit = totalRevenue - totalExpenses;

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: _arabicFont, bold: _arabicFontBold),
        build: (context) => [
          pw.Text('تقرير مالي شامل', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text('من ${DateFormat('d/M/yyyy').format(from)} إلى ${DateFormat('d/M/yyyy').format(to)}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.Divider(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryBox('الإيرادات', totalRevenue, PdfColors.green700),
              _summaryBox('المديونيات', totalDebts, PdfColors.red700),
              _summaryBox('المصروفات', totalExpenses, PdfColors.orange700),
              _summaryBox('صافي الربح', netProfit, netProfit >= 0 ? PdfColors.blue700 : PdfColors.red700),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('الطلبات', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
         pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.brown700),
            cellAlignment: pw.Alignment.centerRight,
            headers: ['العميل', 'الصنف', 'الحالة', 'الإجمالي', 'المتبقي'],
            data: orders
                .map((o) => [o.customerName, o.itemType, o.status, _currency.format(o.totalAmount), _currency.format(o.remainingAmount)])
                .toList(),
          ),
          pw.SizedBox(height: 24),
          pw.Text('المصروفات', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.brown700),
            cellAlignment: pw.Alignment.centerRight,
            headers: ['الفئة', 'الوصف', 'التاريخ', 'المبلغ'],
            data: expenses
                .map((e) => [e.category, e.description, DateFormat('d/M/yyyy').format(e.date), _currency.format(e.amount)])
                .toList(),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// إيصال دفعة سريع - يُطبع/يُشارك فورًا بعد تسجيل أي دفعة أو عربون جديد،
  /// من غير ما تحتاج تروح لصفحة التقارير كل مرة
  Future<Uint8List> buildPaymentReceipt({
    required String customerName,
    required String itemType,
    required double amountPaid,
    required String paymentType,
    required double remainingAmount,
    required DateTime paymentDate,
  }) async {
    await _ensureFontsLoaded();
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: _arabicFont, bold: _arabicFontBold),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text('إيصال دفعة', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Tahoun Royal Home', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.Divider(height: 24),
            _receiptRow('اسم العميل', customerName),
            _receiptRow('الصنف', itemType),
            _receiptRow('نوع الدفعة', paymentType == AppConstants.paymentDeposit ? 'عربون' : 'قسط/دفعة'),
            _receiptRow('التاريخ', DateFormat('d/M/yyyy - h:mm a', 'ar').format(paymentDate)),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('المبلغ المدفوع', style: const pw.TextStyle(fontSize: 13)),
                      pw.Text(_currency.format(amountPaid),
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('المتبقي بعد الدفعة', style: const pw.TextStyle(fontSize: 13)),
                      pw.Text(_currency.format(remainingAmount),
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: remainingAmount > 0 ? PdfColors.red700 : PdfColors.green700)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  pw.Widget _receiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  pw.Widget _summaryBox(String label, double value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(_currency.format(value), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  /// فتح نافذة الطباعة/المشاركة/الحفظ مباشرة
  Future<void> sharePdf(Uint8List bytes, String fileName) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
