import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/app_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction_model.dart';
import '../../models/expense_model.dart';
import '../../models/order_model.dart';
import '../../services/pdf_export_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/privacy_blur.dart';

/// بيبني نص تفاصيل الطلب - الصنف والمواصفات وتاريخ التسليم والحالة، من غير
/// أي تفاصيل مالية (الإجمالي/المدفوع/المتبقي/الخصم) عشان دي بيانات خاصة
/// بالورشة ومش المفروض تتشارك مع حد برا
String _buildFullOrderShareText(OrderModel order) {
  final buffer = StringBuffer()
    ..writeln('طلب: ${order.itemType}')
    ..writeln('العميل: ${order.customerName}');
  if (order.details.trim().isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('المواصفات:')
      ..writeln(order.details.trim());
  }
  buffer
    ..writeln()
    ..writeln('تاريخ التسليم: ${DateFormat('d/M/yyyy').format(order.deliveryDate)}')
    ..writeln('الحالة: ${order.status}');
  return buffer.toString();
}

/// بينزّل صور الطلب من Cloudinary لملفات مؤقتة على الجهاز عشان تتبعت مع
/// نص المشاركة في نفس الرسالة (بعكس الديسكتوب، تطبيقات المشاركة على
/// الموبايل بتقدر ترفق صور وملفات حقيقية مباشرة)
Future<List<XFile>> _downloadOrderImagesAsFiles(OrderModel order) async {
  if (order.images.isEmpty) return [];
  final files = <XFile>[];
  try {
    final tempDir = await getTemporaryDirectory();
    for (var i = 0; i < order.images.length; i++) {
      try {
        final response = await http.get(Uri.parse(order.images[i]));
        if (response.statusCode == 200) {
          final ext = order.images[i].split('.').last.split('?').first;
          final file = File('${tempDir.path}/order_${order.id}_image_$i.$ext');
          await file.writeAsBytes(response.bodyBytes);
          files.add(XFile(file.path));
        }
      } catch (_) {
        // نتجاهل أي صورة فشل تنزيلها ونكمل الباقي
      }
    }
  } catch (_) {}
  return files;
}

Future<void> _shareOrder(BuildContext context, OrderModel order) async {
  final text = _buildFullOrderShareText(order);
  final imageFiles = await _downloadOrderImagesAsFiles(order);
  if (imageFiles.isNotEmpty) {
    await Share.shareXFiles(imageFiles, text: text);
  } else {
    await Share.share(text);
  }
}

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        actions: [
          Builder(
            builder: (context) {
              final order = (ordersAsync.value ?? []).where((o) => o.id == orderId).firstOrNull;
              return IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: 'مشاركة الطلب',
                onPressed: order == null ? null : () => _shareOrder(context, order),
              );
            },
          ),
          Builder(
            builder: (context) {
              final order = (ordersAsync.value ?? []).where((o) => o.id == orderId).firstOrNull;
              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'تعديل الطلب',
                onPressed: order == null ? null : () => context.push('/orders/$orderId/edit'),
              );
            },
          ),
          IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'حذف الطلب',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('حذف الطلب'),
                    content: const Text('هل أنت متأكد من حذف هذا الطلب؟ لا يمكن التراجع عن هذا الإجراء.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(firebaseServiceProvider).deleteOrder(orderId);
                  await NotificationService.instance.cancelOrderReminders(orderId);
                  if (context.mounted) context.pop();
                }
              },
            ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) {
          final order = orders.where((o) => o.id == orderId).firstOrNull;
          if (order == null) return const Center(child: Text('الطلب غير موجود'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${order.customerName} - ${order.itemType}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (order.details.isNotEmpty) Text(order.details, style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 12),
                      Text('تاريخ التسليم المتوقع: ${DateFormat('d MMM yyyy', 'ar').format(order.deliveryDate)}'),
                      if (order.images.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: order.images.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    child: InteractiveViewer(child: Image.network(order.images[i])),
                                  ),
                                ),
                                child: Image.network(order.images[i], width: 90, height: 90, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: order.status,
                        decoration: const InputDecoration(labelText: 'حالة الطلب'),
                        items: AppConstants.orderStatuses
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            ref.read(firebaseServiceProvider).updateOrderStatus(order.id, v);
                            if (v == 'تم التسليم') {
                              NotificationService.instance.cancelOrderReminders(order.id);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
               color: order.remainingAmount > 0 
  ? AppColors.danger.withValues(alpha: 0.08) 
  : AppColors.success.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (order.discountAmount > 0) ...[
                        Text(
                          'الاتفاق الأصلي: ${order.totalAmount.toStringAsFixed(0)} ج.م - خصم ${order.discountAmount.toStringAsFixed(0)} ج.م'
                          '${order.discountReason.isNotEmpty ? ' (${order.discountReason})' : ''}',
                          style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _MoneyBox(label: 'الإجمالي', value: order.totalAmount - order.discountAmount),
                          _MoneyBox(label: 'المدفوع', value: order.totalPaid, color: AppColors.success),
                          _MoneyBox(label: 'المتبقي', value: order.remainingAmount,
                              color: order.remainingAmount > 0 ? AppColors.danger : AppColors.success),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (order.remainingAmount > 0)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showAddPaymentDialog(
                                  context,
                                  ref,
                                  orderId: order.id,
                                  customerId: order.customerId,
                                  customerName: order.customerName,
                                  itemType: order.itemType,
                                  maxAmount: order.remainingAmount,
                                ),
                                icon: const Icon(Icons.add_card_rounded),
                                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('تسجيل دفعة', maxLines: 1)),
                              ),
                            ),
                          if (order.remainingAmount > 0) const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showAddOrderExpenseDialog(
                                context,
                                ref,
                                orderId: order.id,
                                customerId: order.customerId,
                                customerName: order.customerName,
                              ),
                              icon: const Icon(Icons.receipt_long_rounded),
                              label: const FittedBox(fit: BoxFit.scaleDown, child: Text('تسجيل مصروف', maxLines: 1)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.warning,
                            side: const BorderSide(color: AppColors.warning),
                          ),
                          onPressed: () => _showDiscountDialog(context, ref, order),
                          icon: const Icon(Icons.percent_rounded),
                          label: Text(order.discountAmount > 0 ? 'تعديل الخصم' : 'عمل خصم'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('سجل الدفعات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              StreamBuilder<List<TransactionModel>>(
                stream: ref.read(firebaseServiceProvider).streamTransactionsForOrder(order.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final txs = snapshot.data!;
                  if (txs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('لا توجد دفعات مسجلة بعد', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Column(
                    children: txs.map((t) {
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            t.paymentType == AppConstants.paymentDeposit ? Icons.savings_rounded : Icons.payments_rounded,
                            color: AppColors.wood,
                          ),
                          title: Text('${t.amountPaid.toStringAsFixed(0)} ج.م'),
                          subtitle: Text(t.paymentType == AppConstants.paymentDeposit ? 'عربون' : 'قسط/دفعة'),
                          trailing: Text(DateFormat('d/M/yyyy').format(t.paymentDate)),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('مصروفات هذا الطلب', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Consumer(
                builder: (context, ref, _) {
                  final expenses = (ref.watch(expensesStreamProvider).value ?? [])
                      .where((e) => e.orderId == order.id || e.orderAllocations.any((a) => a.orderId == order.id))
                      .toList()
                    ..sort((a, b) => b.date.compareTo(a.date));
                  if (expenses.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('لا توجد مصروفات مرتبطة بهذا الطلب', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Column(
                    children: expenses.map((e) {
                      final allocation = e.orderAllocations.where((a) => a.orderId == order.id).firstOrNull;
                      final shownAmount = allocation?.amount ?? e.amount;
                      final isSplit = e.orderAllocations.length > 1;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long_rounded, color: AppColors.woodDark),
                          title: Text('${shownAmount.toStringAsFixed(0)} ج.م - ${AppConstants.expenseCategories[e.category] ?? e.category}'),
                          subtitle: Text(
                            [
                              if (e.description.isNotEmpty) e.description,
                              if (isSplit) 'مقسّم على ${e.orderAllocations.length} طلبات',
                            ].join(' | '),
                          ),
                          trailing: Text(DateFormat('d/M/yyyy').format(e.date)),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }

  void _showAddOrderExpenseDialog(
    BuildContext context,
    WidgetRef ref, {
    required String orderId,
    required String customerId,
    required String customerName,
  }) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    String category = AppConstants.expenseCategories.keys.firstWhere((k) => k != 'workshop_debt');
    String paymentMethod = 'cash';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة مصروف على الطلب'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'المبلغ (ج.م)'),
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'أدخل مبلغ صحيح' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'الفئة'),
                    items: AppConstants.expenseCategories.entries
                        .where((e) => e.key != 'workshop_debt')
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => category = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(labelText: 'مصدر الدفع'),
                    items: AppConstants.paymentMethods.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => paymentMethod = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'وصف (اختياري)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(firebaseServiceProvider).addExpense(ExpenseModel(
                              id: '',
                              amount: double.parse(amountController.text),
                              category: category,
                              description: descriptionController.text.trim(),
                              orderId: orderId,
                              customerId: customerId,
                              customerName: customerName,
                              paymentMethod: paymentMethod,
                              date: DateTime.now(),
                            ));
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                        }
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDiscountDialog(BuildContext context, WidgetRef ref, OrderModel order) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(
      text: order.discountAmount > 0 ? order.discountAmount.toStringAsFixed(0) : '',
    );
    final reasonController = TextEditingController(text: order.discountReason);
    final maxDiscount = order.totalAmount - order.totalPaid;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خصم على الطلب'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'الخصم مبلغ ثابت (مش نسبة) - بيتشال من الاتفاق الأصلي (${order.totalAmount.toStringAsFixed(0)} ج.م)، '
                  'ومش بيتحسب مديونية عليه ولا إيراد للورشة',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'مبلغ الخصم (ج.م)'),
                validator: (v) {
                  final amount = double.tryParse(v ?? '');
                  if (amount == null || amount < 0) return 'أدخل مبلغ صحيح';
                  if (amount > maxDiscount) return 'الخصم أكبر من المتبقي (${maxDiscount.toStringAsFixed(0)} ج.م)';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(controller: reasonController, decoration: const InputDecoration(labelText: 'السبب (اختياري)')),
            ],
          ),
        ),
        actions: [
          if (order.discountAmount > 0)
            TextButton(
              onPressed: () async {
                await ref.read(firebaseServiceProvider).updateOrder(
                      order.copyWith(discountAmount: 0, discountReason: ''),
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('إلغاء الخصم', style: TextStyle(color: AppColors.danger)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final amount = double.parse(amountController.text.trim());
              await ref.read(firebaseServiceProvider).updateOrder(
                    order.copyWith(discountAmount: amount, discountReason: reasonController.text.trim()),
                  );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentDialog(
    BuildContext screenContext,
    WidgetRef ref, {
    required String orderId,
    required String customerId,
    required String customerName,
    required String itemType,
    required double maxAmount,
  }) {
    final controller = TextEditingController();
    String paymentMethod = 'cash';
    showDialog(
      context: screenContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تسجيل دفعة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'المبلغ (المتبقي ${maxAmount.toStringAsFixed(0)} ج.م)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: AppConstants.paymentMethods.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setDialogState(() => paymentMethod = v!),
              ),
            ],
          ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text.trim());
              if (amount == null || amount <= 0) return;
              await ref.read(firebaseServiceProvider).addPayment(
                    orderId: orderId,
                    customerId: customerId,
                    amount: amount,
                    paymentType: AppConstants.paymentInstallment,
                    paymentMethod: paymentMethod,
                  );
              if (context.mounted) Navigator.pop(context);
              if (screenContext.mounted) {
                ScaffoldMessenger.of(screenContext).showSnackBar(
                  const SnackBar(content: Text('تم تسجيل الدفعة'), duration: Duration(seconds: 2)),
                );
                final paymentDate = DateTime.now();
                final remainingAfter = (maxAmount - amount).clamp(0, double.infinity).toDouble();
                final bytes = await PdfExportService.instance.buildPaymentReceipt(
                  customerName: customerName,
                  itemType: itemType,
                  amountPaid: amount,
                  paymentType: AppConstants.paymentInstallment,
                  remainingAmount: remainingAfter,
                  paymentDate: paymentDate,
                );
                if (screenContext.mounted) {
                  await PdfExportService.instance.preview(screenContext, bytes, 'إيصال_دفعة.pdf');
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
      ),
    );
  }
}

class _MoneyBox extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;
  const _MoneyBox({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 4),
       PrivacyBlur(
          child: Text(value.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        ),
      ],
    );
  }
}
