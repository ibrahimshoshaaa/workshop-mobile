import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/auth_state.dart';
import '../../widgets/stat_card.dart';
import '../../local/local_cache_service.dart';
import '../../services/notification_service.dart';
import '../../models/order_model.dart';
import '../../providers/privacy_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final orders = ref.watch(ordersStreamProvider).value ?? [];
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));

    // تجديد تنبيه المديونيات كل ما بيانات المديونيات تتغيّر
    ref.listen<AsyncValue<List<OrderModel>>>(debtorOrdersStreamProvider, (previous, next) {
      final debtors = next.value ?? [];
      final total = debtors.fold<double>(0, (sum, o) => sum + o.remainingAmount);
      NotificationService.instance.scheduleDebtReminder(total, debtors.length);
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
          Consumer(
            builder: (context, ref, _) {
              final isPrivate = ref.watch(privacyModeProvider);
              return IconButton(
                icon: Icon(isPrivate ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                tooltip: isPrivate ? 'إظهار الأرقام' : 'إخفاء الأرقام',
                onPressed: () => ref.read(privacyModeProvider.notifier).toggle(),
              );
            },
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
                  onTap: () => context.push('/reports/revenue-detail'),
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
                  title: 'المتاح نقدي (كاش)',
                  value: stats.cashAvailable,
                  icon: Icons.payments_rounded,
                  color: stats.cashAvailable >= 0 ? AppColors.success : AppColors.danger,
                ),
                StatCard(
                  title: 'المتاح إنستاباي',
                  value: stats.instapayAvailable,
                  icon: Icons.phone_iphone_rounded,
                  color: stats.instapayAvailable >= 0 ? AppColors.navy : AppColors.danger,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('التسليمات القريبة (خلال أسبوع)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (upcomingDeliveries.isNotEmpty)
                  IconButton(
                    tooltip: 'مشاركة القائمة على واتساب',
                    icon: const Icon(Icons.share_rounded, color: AppColors.success),
                    onPressed: () => _shareUpcomingDeliveries(upcomingDeliveries),
                  ),
              ],
            ),
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

  void _shareUpcomingDeliveries(List<OrderModel> upcomingDeliveries) {
    final formatter = DateFormat('d/M/yyyy', 'ar');
    final buffer = StringBuffer('📦 التسليمات القادمة خلال أسبوع:\n\n');
    for (final o in upcomingDeliveries) {
      buffer.writeln('- ${o.customerName} (${o.itemType}) - ${formatter.format(o.deliveryDate)}');
    }
    Share.share(buffer.toString());
  }
}
