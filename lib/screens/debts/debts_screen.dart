import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

/// صفحة المديونيات - تعرض كل الطلبات التي عليها مبلغ متبقٍ
/// مرتبة تلقائيًا من الأعلى مديونية إلى الأقل (عبر debtorOrdersStreamProvider في app_providers.dart)
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtorsAsync = ref.watch(debtorOrdersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المديونيات')),
      body: debtorsAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Text('لا توجد مديونيات حاليًا 🎉', style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }
          final totalDebt = orders.fold<double>(0, (sum, o) => sum + o.remainingAmount);
          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text('إجمالي المديونيات المستحقة', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 6),
                    Text('${totalDebt.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.danger)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final o = orders[index];
                    final isUrgent = o.deliveryDate.isBefore(DateTime.now().add(const Duration(days: 3)));
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.danger.withOpacity(0.15),
                          child: const Icon(Icons.priority_high_rounded, color: AppColors.danger),
                        ),
                        title: Text('${o.customerName} - ${o.itemType}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'تسليم: ${DateFormat('d MMM', 'ar').format(o.deliveryDate)}'
                          '${isUrgent ? ' ⚠️ قريب' : ''}',
                          style: TextStyle(color: isUrgent ? AppColors.danger : Colors.grey.shade600),
                        ),
                        trailing: Text(
                          '${o.remainingAmount.toStringAsFixed(0)} ج.م',
                          style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onTap: () => context.push('/orders/${o.id}'),
                      ),
                    );
                  },
                ),
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
