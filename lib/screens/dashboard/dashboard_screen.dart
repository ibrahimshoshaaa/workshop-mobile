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
import '../../models/worker_model.dart';
import '../../providers/privacy_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final orders = ref.watch(ordersStreamProvider).value ?? [];
    final dueWorkers = AuthState.can('workers') ? ref.watch(workersDueTodayProvider) : <WorkerModel>[];
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
        title: const Text('Tahoun Royal Home'),
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
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'باقي الأقسام',
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (context) => SafeArea(
                child: Wrap(
                  children: [
                    if (AuthState.can('workers'))
                      ListTile(
                        leading: const Icon(Icons.badge_rounded, color: AppColors.wood),
                        title: const Text('العمال'),
                        subtitle: const Text('المرتبات والقبض الدوري'),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/workers');
                        },
                      ),
                    if (AuthState.can('debts'))
                      ListTile(
                        leading: const Icon(Icons.handshake_rounded, color: AppColors.woodDark),
                        title: const Text('ديون الورشة'),
                        subtitle: const Text('مستحقات الموردين والصنايعية'),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/workshop-debts');
                        },
                      ),
                    if (AuthState.can('reports'))
                      ListTile(
                        leading: const Icon(Icons.bar_chart_rounded, color: AppColors.navy),
                        title: const Text('التقارير'),
                        subtitle: const Text('الإيرادات والتحليلات'),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/reports');
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (AuthState.isAdmin)
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
                  title: 'المديونيات المستحقة',
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
                  onTap: () => _showCashTransferDialog(context, ref, stats.instapayAvailable),
                ),
                StatCard(
                  title: 'مديونيات الورشة (علينا)',
                  value: stats.totalWorkshopDebts,
                  icon: Icons.store_rounded,
                  color: AppColors.danger,
                  onTap: () => context.push('/workshop-debts'),
                ),
              ],
            ),
            if (dueWorkers.isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                color: AppColors.warning.withOpacity(0.1),
                child: ListTile(
                  leading: const Icon(Icons.notifications_active_rounded, color: AppColors.warning),
                  title: const Text('النهاردة يوم القبض الأسبوعي', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('مستني تأكيد الدفع: ${dueWorkers.map((w) => w.name).join('، ')}'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => context.push('/workers'),
                ),
              ),
            ],
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
                      onTap: () => context.push('/orders/${o.id}'),
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

  /// سحب رصيد إنستاباي عن طريق الصراف الآلي وتحويله لكاش - بينقل المبلغ
  /// من "المتاح إنستاباي" لـ "المتاح نقدي" في الداشبورد. تحت الفورم فيه
  /// سجل بآخر العمليات يقدر يحذف منه أي عملية غلط
  void _showCashTransferDialog(BuildContext context, WidgetRef ref, double availableInstapay) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('سحب إنستاباي كاش'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المتاح حاليًا في إنستاباي: ${availableInstapay.toStringAsFixed(0)} ج.م',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Form(
                    key: formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'المبلغ اللي اتسحب (ج.م)'),
                          validator: (v) {
                            final amount = double.tryParse(v ?? '');
                            if (amount == null || amount <= 0) return 'أدخل مبلغ صحيح';
                            if (amount > availableInstapay) {
                              return 'المبلغ أكبر من المتاح في إنستاباي (${availableInstapay.toStringAsFixed(0)} ج.م)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: noteController,
                          decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 28),
                  const Text('آخر العمليات', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Consumer(
                    builder: (context, ref, _) {
                      final transfers = ref.watch(cashTransfersStreamProvider).value ?? [];
                      if (transfers.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('لا توجد عمليات سحب مسجّلة بعد', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        );
                      }
                      return Column(
                        children: transfers.take(5).map((t) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text('${t.amount.toStringAsFixed(0)} ج.م'),
                            subtitle: Text(
                              [
                                DateFormat('d/M/yyyy').format(t.date),
                                if (t.note.isNotEmpty) t.note,
                              ].join(' - '),
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                              onPressed: () => ref.read(firebaseServiceProvider).deleteCashTransfer(t.id),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(firebaseServiceProvider).addCashTransfer(
                              double.parse(amountController.text.trim()),
                              note: noteController.text.trim(),
                            );
                        amountController.clear();
                        noteController.clear();
                        setDialogState(() => isSaving = false);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                        }
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('تسجيل السحب'),
            ),
          ],
        ),
      ),
    );
  }
}
