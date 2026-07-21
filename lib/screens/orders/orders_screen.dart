import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/privacy_blur.dart';

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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث باسم العميل أو نوع الصنف...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => ref.read(orderSearchQueryProvider.notifier).state = v,
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _FilterChip(
                  label: 'الكل',
                  selected: selectedStatus == null,
                  onTap: () => ref.read(orderStatusFilterProvider.notifier).state = null,
                ),
                const SizedBox(width: 8),
                ...AppConstants.orderStatuses.map((s) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FilterChip(
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
                ? const Center(child: Text('لا توجد طلبات', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final o = orders[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(o.status).withValues(alpha: 0.15),
                            child: Icon(Icons.checkroom_rounded, color: _statusColor(o.status)),
                          ),
                          title: Text('${o.customerName} - ${o.itemType}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              'تسليم: ${DateFormat('d MMM yyyy', 'ar').format(o.deliveryDate)} | ${o.status}'),
                         trailing: o.remainingAmount > 0
                              ? PrivacyBlur(
                                  child: Text(
                                    'متبقي ${o.remainingAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                                  ),
                                )
                              : const Text('مكتمل', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)), onTap: () => context.push('/orders/${o.id}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.wood,
      // كان لون النص غير المختار متثبّت على Colors.black87 دايمًا، وده باين
      // كويس على خلفية فاتحة بس بيبقى شبه مختفي على خلفية الوضع الداكن
      // (نص شبه أسود على خلفية شبه سودا). دلوقتي بياخد لون مناسب للثيم
      labelStyle: TextStyle(color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
    );
  }
}
