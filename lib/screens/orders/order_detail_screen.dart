import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../providers/app_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction_model.dart';
import '../../services/pdf_export_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/privacy_blur.dart';

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _MoneyBox(label: 'الإجمالي', value: order.totalAmount),
                          _MoneyBox(label: 'المدفوع', value: order.totalPaid, color: AppColors.success),
                          _MoneyBox(label: 'المتبقي', value: order.remainingAmount,
                              color: order.remainingAmount > 0 ? AppColors.danger : AppColors.success),
                        ],
                      ),
                      if (order.remainingAmount > 0) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
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
                          label: const Text('تسجيل دفعة جديدة'),
                        ),
                      ],
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
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }

  void _showAddPaymentDialog(
    BuildContext context,
    WidgetRef ref, {
    required String orderId,
    required String customerId,
    required String customerName,
    required String itemType,
    required double maxAmount,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل دفعة'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'المبلغ (المتبقي ${maxAmount.toStringAsFixed(0)} ج.م)',
          ),
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
                  );
              if (context.mounted) {
                Navigator.pop(context);
                final messenger = ScaffoldMessenger.of(context);
                final paymentDate = DateTime.now();
                final remainingAfter = (maxAmount - amount).clamp(0, double.infinity).toDouble();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('تم تسجيل الدفعة'),
                    action: SnackBarAction(
                      label: 'طباعة إيصال',
                      onPressed: () async {
                        final bytes = await PdfExportService.instance.buildPaymentReceipt(
                          customerName: customerName,
                          itemType: itemType,
                          amountPaid: amount,
                          paymentType: AppConstants.paymentInstallment,
                          remainingAmount: remainingAfter,
                          paymentDate: paymentDate,
                        );
                        await PdfExportService.instance.sharePdf(bytes, 'إيصال_دفعة.pdf');
                      },
                    ),
                    duration: const Duration(seconds: 6),
                  ),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
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
