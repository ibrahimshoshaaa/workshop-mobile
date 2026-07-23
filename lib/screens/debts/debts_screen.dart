import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/privacy_blur.dart';
import '../../widgets/modern_ui.dart';

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
            return const ModernEmptyState(icon: Icons.celebration_outlined, message: 'لا توجد مديونيات حاليًا 🎉');
          }
          final totalDebt = orders.fold<double>(0, (sum, o) => sum + o.remainingAmount);
          return Column(
            children: [
              ModernSummaryBanner(
                icon: Icons.people_alt_rounded,
                color: AppColors.danger,
                label: 'إجمالي المديونيات المستحقة',
                value: PrivacyBlur(child: Text('${totalDebt.toStringAsFixed(0)} ج.م')),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final o = orders[index];
                    final isUrgent = o.deliveryDate.isBefore(DateTime.now().add(const Duration(days: 3)));
                    return ModernListCard(
                      leading: const ModernIconBadge(icon: Icons.priority_high_rounded, color: AppColors.danger),
                      title: Text('${o.customerName} - ${o.itemType}', overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        'تسليم: ${DateFormat('d MMM', 'ar').format(o.deliveryDate)}'
                        '${isUrgent ? ' ⚠️ قريب' : ''}',
                        style: TextStyle(color: isUrgent ? AppColors.danger : null),
                      ),
                      trailing: PrivacyBlur(
                        child: Text(
                          '${o.remainingAmount.toStringAsFixed(0)} ج.م',
                          style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      onTap: () => context.push('/orders/${o.id}'),
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
