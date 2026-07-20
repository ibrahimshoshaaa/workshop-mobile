import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../providers/app_providers.dart';
import '../../services/pdf_export_service.dart';
import '../../services/excel_export_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String? _selectedCustomerId;
  String? _selectedOrderId;
  bool _isExporting = false;

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _exportFinancialPdf() async {
    setState(() => _isExporting = true);
    try {
      final orders = (ref.read(ordersStreamProvider).value ?? [])
          .where((o) => o.createdAt.isAfter(_range.start) && o.createdAt.isBefore(_range.end.add(const Duration(days: 1))))
          .toList();
      final expenses = (ref.read(expensesStreamProvider).value ?? [])
          .where((e) => e.date.isAfter(_range.start) && e.date.isBefore(_range.end.add(const Duration(days: 1))))
          .toList();

      final bytes = await PdfExportService.instance.buildFinancialReport(
        orders: orders,
        expenses: expenses,
        from: _range.start,
        to: _range.end,
      );
      if (mounted) await PdfExportService.instance.preview(context, bytes, 'تقرير_مالي.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportFinancialExcel() async {
    setState(() => _isExporting = true);
    try {
      final orders = (ref.read(ordersStreamProvider).value ?? [])
          .where((o) => o.createdAt.isAfter(_range.start) && o.createdAt.isBefore(_range.end.add(const Duration(days: 1))))
          .toList();
      final expenses = (ref.read(expensesStreamProvider).value ?? [])
          .where((e) => e.date.isAfter(_range.start) && e.date.isBefore(_range.end.add(const Duration(days: 1))))
          .toList();

      final bytes = ExcelExportService.instance.buildFinancialWorkbook(orders: orders, expenses: expenses);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/تقرير_مالي.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'التقرير المالي - Tahoun Royal Home');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportCustomerInvoice() async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر العميل أولاً')));
      return;
    }
    setState(() => _isExporting = true);
    try {
      final customers = ref.read(customersStreamProvider).value ?? [];
      final customer = customers.firstWhere((c) => c.id == _selectedCustomerId);
      var orders = (ref.read(ordersStreamProvider).value ?? [])
          .where((o) => o.customerId == _selectedCustomerId)
          .toList();
      if (_selectedOrderId != null) {
        orders = orders.where((o) => o.id == _selectedOrderId).toList();
      }

      final bytes = await PdfExportService.instance.buildCustomerInvoice(customer: customer, orders: orders);
      final fileSuffix = orders.length == 1 ? '${customer.name}_${orders.first.itemType}' : customer.name;
      if (mounted) await PdfExportService.instance.preview(context, bytes, 'فاتورة_$fileSuffix.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersStreamProvider).value ?? [];
    final allOrders = ref.watch(ordersStreamProvider).value ?? [];
    final customerOrders = _selectedCustomerId == null
        ? const <OrderModel>[]
        : allOrders.where((o) => o.customerId == _selectedCustomerId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والتصدير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_rows_rounded),
            tooltip: 'تفاصيل الإيرادات',
            onPressed: () => context.push('/reports/revenue-detail'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isExporting,
        child: Opacity(
          opacity: _isExporting ? 0.5 : 1,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('التقرير المالي الشامل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('الفترة الزمنية'),
                        subtitle: Text(
                            '${_range.start.year}/${_range.start.month}/${_range.start.day} - ${_range.end.year}/${_range.end.month}/${_range.end.day}'),
                        trailing: const Icon(Icons.date_range_rounded),
                        onTap: _pickRange,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _exportFinancialPdf,
                              icon: const Icon(Icons.picture_as_pdf_rounded),
                              label: const Text('PDF'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _exportFinancialExcel,
                              icon: const Icon(Icons.table_chart_rounded),
                              label: const Text('Excel'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('فاتورة عميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedCustomerId,
                        decoration: const InputDecoration(labelText: 'اختر العميل'),
                        items: customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (v) => setState(() {
                          _selectedCustomerId = v;
                          _selectedOrderId = null;
                        }),
                      ),
                      if (_selectedCustomerId != null && customerOrders.length > 1) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          value: _selectedOrderId,
                          decoration: const InputDecoration(labelText: 'نوع الطلب'),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('كل الطلبات')),
                            ...customerOrders.map((o) => DropdownMenuItem<String?>(
                                  value: o.id,
                                  child: Text('${o.itemType} - ${DateFormat('d/M/yyyy').format(o.deliveryDate)}'),
                                )),
                          ],
                          onChanged: (v) => setState(() => _selectedOrderId = v),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _exportCustomerInvoice,
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text('تصدير فاتورة PDF'),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isExporting) const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      ),
    );
  }
}
