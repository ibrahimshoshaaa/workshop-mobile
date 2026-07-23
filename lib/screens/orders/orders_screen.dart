import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/privacy_blur.dart';
import '../../widgets/modern_ui.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'جاري التجهيز':
        return Colors.grey.shade600;
      case 'قيد التنفيذ':
        return AppColors.navy;
      case 'جاهز للتسليم':
        return AppColors.warning;
      case 'تم التسليم':
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(filteredOrdersProvider);
    final selectedStatus = ref.watch(orderStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الطلبات')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.wood,
        onPressed: () => context.push('/orders/add'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ModernSearchField(
              hint: 'ابحث باسم العميل أو نوع الصنف...',
              onChanged: (v) => ref.read(orderSearchQueryProvider.notifier).state = v,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                ModernChip(
                  label: 'الكل',
                  selected: selectedStatus == null,
                  onTap: () => ref.read(orderStatusFilterProvider.notifier).state = null,
                ),
                const SizedBox(width: 8),
                ...AppConstants.orderStatuses.map((s) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ModernChip(
                        label: s,
                        selected: selectedStatus == s,
                        onTap: () => ref.read(orderStatusFilterProvider.notifier).state = s,
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: orders.isEmpty
                ? const ModernEmptyState(icon: Icons.checkroom_outlined, message: 'لا توجد طلبات')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final o = orders[index];
                      return ModernListCard(
                        leading: ModernIconBadge(icon: Icons.checkroom_rounded, color: _statusColor(o.status)),
                        title: Text('${o.customerName} - ${o.itemType}', overflow: TextOverflow.ellipsis),
                        subtitle: Text('تسليم: ${DateFormat('d MMM yyyy', 'ar').format(o.deliveryDate)} | ${o.status}'),
                        trailing: o.remainingAmount > 0
                            ? PrivacyBlur(
                                child: Text(
                                  'متبقي ${o.remainingAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                              )
                            : const Text('مكتمل', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12.5)),
                        onTap: () => context.push('/orders/${o.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


