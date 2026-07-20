import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
  pw.MemoryImage? _logo;

  Future<void> _ensureFontsLoaded() async {
    _arabicFont ??= await PdfGoogleFonts.cairoRegular();
    _arabicFontBold ??= await PdfGoogleFonts.cairoBold();
    if (_logo == null) {
      final data = await rootBundle.load('assets/icon/app_icon.png');
      _logo = pw.MemoryImage(data.buffer.asUint8List());
    }
  }

  /// شعار الشركة - بيتحط جنب العنوان في أول أي مستند (فاتورة/تقرير/إيصال)
  pw.Widget _logoWidget({double size = 44}) {
    if (_logo == null) return pw.SizedBox(width: size, height: size);
    return pw.ClipRRect(
      horizontalRadius: size / 4,
      verticalRadius: size / 4,
      child: pw.Image(_logo!, width: size, height: size, fit: pw.BoxFit.cover),
    );
  }

  final _currency = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 0);

  /// عربي Locale بيضيف حروف اتجاه مخفية (bidi/format marks) جوه النص عشان
  /// يظبط ترتيب الأرقام والعملة، بس خط Cairo مالوش شكل ليها فبتظهر كمربع
  /// فاضي "تُفُو". الميثود دي بتشيل أي حرف مخفي من النوع ده وتستبدل الـ
  /// non-breaking space بمسافة عادية، عشان النص يترسم نضيف من غير علامات غريبة.
  static final RegExp _invisibleChars = RegExp(
    r'[\u200B-\u200F\u202A-\u202E\u2066-\u2069\u061C\uFEFF]',
  );

  /// بتتشال منها أي حرف اتجاه/تنسيق مخفي (bidi/format marks) قبل ما يتحط
  /// في أي pw.Text - سواء كان رقم متنسّق أو نص عادي جاي من بيانات المستخدم
  /// (اسم، تليفون، عنوان، حالة، صنف...إلخ). النصوص دي ممكن توصل من الكيبورد
  /// أو من التاريخ بلوكال عربي وفيها نفس الحروف المخفية اللي بتبوظ الرسم.
  String _clean(String input) => input.replaceAll('\u00A0', ' ').replaceAll(_invisibleChars, '');

  /// استخدم الدالة دي مع أي String ديناميكي (مش ثابت) قبل عرضه في الـ PDF.
  String _s(String input) => _clean(input);

  String _fmt(double value) => _clean(_currency.format(value));

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
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('فاتورة عميل', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Tahoun Royal Home', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              _logoWidget(),
            ],
          ),
          pw.Divider(height: 24),
          pw.Text('اسم العميل: ${_s(customer.name)}', style: const pw.TextStyle(fontSize: 14)),
          pw.Text('رقم الهاتف: ${_s(customer.phone)}', style: const pw.TextStyle(fontSize: 14)),
          if (customer.address.isNotEmpty) pw.Text('العنوان: ${_s(customer.address)}', style: const pw.TextStyle(fontSize: 14)),
          pw.Text('تاريخ الإصدار: ${DateFormat('d/M/yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: _arabicFontBold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.brown700),
            cellStyle: pw.TextStyle(font: _arabicFont),
            cellAlignment: pw.Alignment.centerRight,
            headers: ['المتبقي', 'المدفوع', 'الإجمالي', 'الحالة', 'الصنف'],
            data: orders
                .map((o) => [
                      _fmt(o.remainingAmount),
                      _fmt(o.totalPaid),
                      _fmt(o.totalAmount),
                      _s(o.status),
                      _s(o.itemType),
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
                pw.Text('إجمالي الاتفاق: ${_fmt(totalAmount)}'),
                pw.SizedBox(height: 4),
                pw.Text('إجمالي المدفوع: ${_fmt(totalPaid)}'),
                pw.SizedBox(height: 4),
                pw.Text('إجمالي المتبقي: ${_fmt(totalRemaining)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: totalRemaining > 0 ? PdfColors.red700 : PdfColors.green700)),
              ],
            ),
          ),
          if (orders.any((o) => o.details.trim().isNotEmpty)) ...[
            pw.SizedBox(height: 20),
            pw.Text('تفاصيل الطلبات', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ...orders.where((o) => o.details.trim().isNotEmpty).map(
                  (o) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(_s(o.itemType), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.SizedBox(height: 4),
                        pw.Text(_s(o.details.trim()), style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                      ],
                    ),
                  ),
                ),
          ],
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
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('تقرير مالي شامل', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text('من ${DateFormat('d/M/yyyy').format(from)} إلى ${DateFormat('d/M/yyyy').format(to)}',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              _logoWidget(),
            ],
          ),
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
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: _arabicFontBold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.brown700),
            cellStyle: pw.TextStyle(font: _arabicFont),
            cellAlignment: pw.Alignment.centerRight,
            headers: ['المتبقي', 'الإجمالي', 'الحالة', 'الصنف', 'العميل'],
            data: orders
                .map((o) => [_fmt(o.remainingAmount), _fmt(o.totalAmount), _s(o.status), _s(o.itemType), _s(o.customerName)])
                .toList(),
          ),
          pw.SizedBox(height: 24),
          pw.Text('المصروفات', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: _arabicFontBold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.brown700),
            cellStyle: pw.TextStyle(font: _arabicFont),
            cellAlignment: pw.Alignment.centerRight,
            headers: ['المبلغ', 'التاريخ', 'الوصف', 'الفئة'],
            data: expenses
                .map((e) => [_fmt(e.amount), DateFormat('d/M/yyyy').format(e.date), _s(e.description), _s(e.category)])
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
            pw.Center(child: _logoWidget(size: 56)),
            pw.SizedBox(height: 8),
            pw.Text('إيصال دفعة', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Tahoun Royal Home', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.Divider(height: 24),
            _receiptRow('اسم العميل', _s(customerName)),
            _receiptRow('الصنف', _s(itemType)),
            _receiptRow('نوع الدفعة', paymentType == AppConstants.paymentDeposit ? 'عربون' : 'قسط/دفعة'),
            _receiptRow('التاريخ', _s(DateFormat('d/M/yyyy - h:mm a', 'ar').format(paymentDate))),
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
                      pw.Text(_fmt(amountPaid),
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('المتبقي بعد الدفعة', style: const pw.TextStyle(fontSize: 13)),
                      pw.Text(_fmt(remainingAmount),
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
          pw.Text(label, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700, font: _arabicFont)),
          pw.Text(value, style: pw.TextStyle(fontSize: 13, font: _arabicFont)),
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
          pw.Text(_fmt(value), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  /// بيفتح شاشة معاينة جوه التطبيق الأول (تعرض شكل التقرير/الفاتورة كامل)،
  /// وبعدين المستخدم هو اللي يقرر: يشارك/يطبع، أو يقفل الشاشة من غير ما
  /// يحصل تصدير خالص. نفس شاشة المعاينة الموجودة في تطبيق الديسكتوب بالظبط.
  Future<void> preview(BuildContext context, Uint8List bytes, String fileName) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('معاينة قبل المشاركة')),
          body: PdfPreview(
            build: (format) async => bytes,
            pdfFileName: fileName,
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
          ),
        ),
      ),
    );
  }

  /// فتح نافذة المشاركة مباشرة من غير معاينة - سايبها موجودة لو احتجتها
  /// في مكان تاني
  Future<void> sharePdf(Uint8List bytes, String fileName) async {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
