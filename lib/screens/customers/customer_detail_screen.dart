import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/privacy_blur.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersStreamProvider);
    final ordersAsync = ref.watch(ordersForCustomerProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملف العميل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'تعديل بيانات العميل',
            onPressed: () => context.push('/customers/$customerId/edit'),
          ),
          IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'حذف العميل',
              onPressed: () async {
                final hasOrders = (ordersAsync.value ?? []).isNotEmpty;
                if (hasOrders) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('لا يمكن حذف عميل له طلبات مسجّلة، احذف طلباته أولاً')),
                  );
                  return;
                }
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('حذف العميل'),
                    content: const Text('هل أنت متأكد من حذف هذا العميل؟'),
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
                  await ref.read(firebaseServiceProvider).deleteCustomer(customerId);
                  if (context.mounted) context.pop();
                }
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.wood,
        onPressed: () => context.push('/orders/add?customerId=$customerId'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('طلب جديد', style: TextStyle(color: Colors.white)),
      ),
      body: customersAsync.when(
        data: (customers) {
          final customer = customers.where((c) => c.id == customerId).firstOrNull;
          if (customer == null) return const Center(child: Text('العميل غير موجود'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(customer.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.wood.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '#${customer.serialNumber}',
                              style: const TextStyle(fontSize: 12, color: AppColors.wood, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(children: [const Icon(Icons.phone, size: 16, color: Colors.grey), const SizedBox(width: 6), Text(customer.phone)]),
                      if (customer.address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [const Icon(Icons.location_on, size: 16, color: Colors.grey), const SizedBox(width: 6), Expanded(child: Text(customer.address))]),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('الطلبات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ordersAsync.when(
                data: (orders) {
                  if (orders.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('لا توجد طلبات لهذا العميل بعد', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Column(
                    children: orders.map((o) {
                      return Card(
                        child: ListTile(
                          title: Text(o.itemType),
                          subtitle: Text('الحالة: ${o.status}'),
                       trailing: o.remainingAmount > 0
                              ? PrivacyBlur(
                                  child: Text('متبقي ${o.remainingAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                                )
                              : const Text('مدفوع بالكامل', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),                          onTap: () => context.push('/orders/${o.id}'),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('خطأ: $e'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}
