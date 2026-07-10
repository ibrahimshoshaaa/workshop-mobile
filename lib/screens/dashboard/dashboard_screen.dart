import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/auth_state.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/monthly_revenue_chart.dart';
import '../../widgets/item_type_pie_chart.dart';
import '../../local/local_cache_service.dart';
import '../../services/notification_service.dart';
import '../../models/order_model.dart';
import '../../models/material_item_model.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final orders = ref.watch(ordersStreamProvider).value ?? [];
    final monthlyRevenue = ref.watch(monthlyRevenueProvider);
    final itemTypeBreakdown = ref.watch(itemTypeBreakdownProvider);
    final lowStock = ref.watch(lowStockMaterialsProvider);
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));

    // تجديد تنبيه المديونيات كل ما بيانات المديونيات تتغيّر
    ref.listen<AsyncValue<List<OrderModel>>>(debtorOrdersStreamProvider, (previous, next) {
      final debtors = next.value ?? [];
      final total = debtors.fold<double>(0, (sum, o) => sum + o.remainingAmount);
      NotificationService.instance.scheduleDebtReminder(total, debtors.length);
    });

    // تجديد تنبيه المخزون كل ما بيانات الخامات تتغيّر
    ref.listen<List<MaterialItemModel>>(lowStockMaterialsProvider, (previous, next) {
      NotificationService.instance.scheduleLowStockReminder(next.map((m) => m.name).toList());
    });

    final upcomingDeliveries = orders
        .where((o) =>
            o.status != 'تم التسليم' &&
            o.deliveryDate.isAfter(now.subtract(const Duration(days: 1))) &&
            o.deliveryDate.isBefore(weekFromNow))
        .toList()
      ..sort((a, b) => a.deliveryDate.compareTo(b.deliveryDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('ورشة التنجيد والأثاث'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.inventory_2_rounded),
                tooltip: 'مخزون الخامات',
                onPressed: () => context.push('/inventory'),
              ),
              if (lowStock.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 8,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.summarize_rounded),
            tooltip: 'التقارير والتصدير',
            onPressed: () => context.push('/reports'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'الإعدادات',
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('تسجيل الخروج')),
                  ],
                ),
              );
              if (confirm == true) {
                await LocalCacheService.instance.clearAll();
                await AuthState.logout();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ordersStreamProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                StatCard(
                  title: 'إجمالي الإيرادات',
                  value: stats.totalRevenue,
                  icon: Icons.trending_up_rounded,
                  color: AppColors.success,
                ),
                StatCard(
                  title: 'إجمالي المديونيات',
                  value: stats.totalDebts,
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.danger,
                ),
                StatCard(
                  title: 'إجمالي المصروفات',
                  value: stats.totalExpenses,
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.warning,
                ),
                StatCard(
                  title: 'صافي الربح',
                  value: stats.netProfit,
                  icon: Icons.account_balance_rounded,
                  color: stats.netProfit >= 0 ? AppColors.navy : AppColors.danger,
                ),
              ],
            ),
            if (lowStock.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: AppColors.danger.withValues(alpha: 0.08),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                  title: const Text('خامات على وشك النفاد', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(lowStock.map((m) => m.name).join('، ')),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => context.push('/inventory'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الإيرادات آخر 6 شهور',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    MonthlyRevenueChart(data: monthlyRevenue),
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
                    Text('توزيع الطلبات حسب النوع',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ItemTypePieChart(data: itemTypeBreakdown),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('التسليمات القريبة (خلال أسبوع)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (upcomingDeliveries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('لا توجد تسليمات مستحقة خلال الأسبوع القادم', style: TextStyle(color: Colors.grey)),
              )
            else
              ...upcomingDeliveries.map((o) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_rounded, color: AppColors.wood),
                      title: Text('${o.customerName} - ${o.itemType}'),
                      subtitle: Text('تسليم: ${DateFormat('d MMM', 'ar').format(o.deliveryDate)} | الحالة: ${o.status}'),
                      trailing: o.remainingAmount > 0
                          ? Text('متبقي ${o.remainingAmount.toStringAsFixed(0)} ج.م',
                              style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold))
                          : const Icon(Icons.check_circle, color: AppColors.success),
                      onTap: () {},
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
