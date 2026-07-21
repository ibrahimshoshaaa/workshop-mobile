import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/auth_state.dart';
import '../../local/local_cache_service.dart';
import '../../services/notification_service.dart';
import '../../models/order_model.dart';
import '../../models/worker_model.dart';
import '../../providers/privacy_provider.dart';
import '../../providers/theme_mode_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static bool _notificationPermissionRequested = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final orders = ref.watch(ordersStreamProvider).value ?? [];
    final customers = ref.watch(customersStreamProvider).value ?? [];
    final customerPhones = {for (final c in customers) c.id: c.phone};
    final dueWorkers = AuthState.can('workers') ? ref.watch(workersDueTodayProvider) : <WorkerModel>[];
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));

    // تجديد تنبيه المديونيات كل ما بيانات المديونيات تتغيّر
    ref.listen<AsyncValue<List<OrderModel>>>(debtorOrdersStreamProvider, (previous, next) {
      final debtors = next.value ?? [];
      final total = debtors.fold<double>(0, (sum, o) => sum + o.remainingAmount);
      NotificationService.instance.scheduleDebtReminder(total, debtors.length);
    });

    // طلب إذن الإشعارات (بيطلّع دياجول نظام) بعد ما الداشبورد يترسم فعليًا
    // وبعد لحظة صغيرة تسمح للواجهة تستقر - بدل ما نطلبه وقت فتح التطبيق
    // على شاشة تسجيل الدخول، اللي كان بيتزامن مع كتابة المستخدم في الحقول
    // ويسبب إغلاق التطبيق مرة واحدة أول استخدام بعد التثبيت.
    // الحارس الثابت بيضمن إن الطلب يحصل مرة واحدة بس في الجلسة كلها.
    if (!_notificationPermissionRequested) {
      _notificationPermissionRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 800), () {
          NotificationService.instance.requestPermission();
        });
      });
    }

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
          Consumer(
            builder: (context, ref, _) {
              final themeMode = ref.watch(appThemeModeProvider);
              // بنحسب "هل الوضع الحالي غامق فعليًا" مش بس بننضر لقيمة الاختيار
              // نفسها، عشان لو الاختيار "حسب النظام" والنظام شغال دارك، الأيقونة
              // تفضل صح مع اللي المستخدم شايفه فعليًا على الشاشة
              final isDarkNow = themeMode == ThemeMode.dark ||
                  (themeMode == ThemeMode.system &&
                      MediaQuery.platformBrightnessOf(context) == Brightness.dark);
              return IconButton(
                icon: Icon(isDarkNow ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                tooltip: isDarkNow ? 'وضع فاتح' : 'وضع غامق',
                onPressed: () => ref.read(appThemeModeProvider.notifier).toggleLightDark(),
              );
            },
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _GreetingHeader(username: AuthState.currentUsername ?? ''),
            const SizedBox(height: 16),
            _HeroCashCard(
              cash: stats.cashAvailable,
              instapay: stats.instapayAvailable,
              onTapInstapay: () => _showCashTransferDialog(context, ref, stats.instapayAvailable),
            ),
            const SizedBox(height: 12),
            _PremiumStatsGrid(
              children: [
                _PremiumStatCard(
                  icon: Icons.trending_up_rounded,
                  color: AppColors.success,
                  value: stats.totalRevenue,
                  label: 'إجمالي الإيرادات',
                  context2: '${orders.length} طلب',
                  onTap: () => context.push('/reports/revenue-detail'),
                ),
                _PremiumStatCard(
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.warning,
                  value: stats.totalExpenses,
                  label: 'إجمالي المصروفات',
                  context2: null,
                  onTap: () => context.push('/expenses'),
                ),
                _PremiumStatCard(
                  icon: Icons.people_alt_rounded,
                  color: AppColors.danger,
                  value: stats.totalDebts,
                  label: 'مديونيات العملاء',
                  context2: '${orders.where((o) => o.remainingAmount > 0).length} طلب متبقي',
                  onTap: () => context.push('/debts'),
                ),
                _PremiumStatCard(
                  icon: Icons.storefront_rounded,
                  color: AppColors.wood,
                  value: stats.totalWorkshopDebts,
                  label: 'مديونيات الورشة',
                  context2: 'علينا',
                  onTap: () => context.push('/workshop-debts'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'طلب جديد',
                    onTap: () => context.push('/orders/add'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.person_add_alt_rounded,
                    label: 'عميل جديد',
                    onTap: () => context.push('/customers/add'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.credit_card_rounded,
                    label: 'تسجيل دفعة',
                    onTap: () {
                      ref.read(orderStatusFilterProvider.notifier).state = null;
                      context.push('/orders');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.local_shipping_rounded,
                    label: 'تسليم طلب',
                    onTap: () {
                      ref.read(orderStatusFilterProvider.notifier).state = 'جاهز للتسليم';
                      context.push('/orders');
                    },
                  ),
                ),
              ],
            ),
            if (dueWorkers.isNotEmpty) ...[
              const SizedBox(height: 20),
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
                Text('الطلبات الحالية', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (upcomingDeliveries.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.ios_share_rounded, size: 20),
                    tooltip: 'مشاركة التسليمات القريبة',
                    onPressed: () => _shareUpcomingDeliveries(upcomingDeliveries),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (upcomingDeliveries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('مفيش تسليمات قريبة خلال أسبوع', style: TextStyle(color: Colors.grey))),
              )
            else
              ...upcomingDeliveries.map((o) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OrderCard(
                      order: o,
                      phone: customerPhones[o.customerId],
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

/// شبكة إحصائيات مرنة - عكس GridView.count بـ childAspectRatio ثابت،
/// كل صف هنا بياخد ارتفاعه من أطول محتوى فيه (IntrinsicHeight)، فلو
/// العنوان طال (شاشة صغيرة، أو خط النظام مكبّر) الكارت بيتمدد لتحت
/// بدل ما النص يطلع بره حدوده
class _PremiumStatsGrid extends StatelessWidget {
  final List<Widget> children;
  const _PremiumStatsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final hasSecond = i + 1 < children.length;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 8),
              Expanded(child: hasSecond ? children[i + 1] : const SizedBox()),
            ],
          ),
        ),
      );
      if (i + 2 < children.length) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }
}

/// تحية بتتغيّر حسب وقت اليوم فعليًا (صباح/مساء) + اسم المستخدم الحالي
class _GreetingHeader extends StatelessWidget {
  final String username;
  const _GreetingHeader({required this.username});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'صباح الخير' : (hour < 17 ? 'مساء النور' : 'مساء الخير');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodySmall?.color)),
        const SizedBox(height: 2),
        Text(
          username.isEmpty ? 'أهلًا بيك' : username,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// الكارت الرئيسي الكبير - المتاح نقدي النهاردة، وتحته صف صغير للمتاح
/// إنستاباي (بيفتح نفس دياجول سحب الكاش القديم لو ضغط عليه)
class _HeroCashCard extends StatelessWidget {
  final double cash;
  final double instapay;
  final VoidCallback onTapInstapay;
  const _HeroCashCard({required this.cash, required this.instapay, required this.onTapInstapay});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat.decimalPattern('ar');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.wood.withOpacity(0.14) : AppColors.wood.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.wood.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المتاح نقدي النهاردة', style: TextStyle(fontSize: 13, color: AppColors.wood)),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${fmt.format(cash)} ج.م',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    ),
                  ),
                ],
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.wood.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.wood),
              ),
            ],
          ),
          const Divider(height: 24),
          InkWell(
            onTap: onTapInstapay,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                const Icon(Icons.phone_iphone_rounded, size: 18, color: AppColors.navy),
                const SizedBox(width: 8),
                const Text('المتاح إنستاباي', style: TextStyle(fontSize: 13)),
                const Spacer(),
                Text('${fmt.format(instapay)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_left_rounded, size: 18, color: AppColors.navy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// كارت إحصائية مضغوط - أيقونة، رقم كبير، عنوان صغير، وسطر سياق حقيقي
/// (مش نسبة نمو مختلقة) زي عدد الطلبات أو حالة الرصيد
class _PremiumStatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double value;
  final String label;
  final String? context2;
  final VoidCallback? onTap;
  const _PremiumStatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.context2,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('ar');
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(fmt.format(value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 2),
              Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
              if (context2 != null) ...[
                const SizedBox(height: 4),
                Text(context2!, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// زرار إجراء سريع - أيقونة جوه دايرة ولابل تحتها، مضغوط عشان يتحط ٤ في صف
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: AppColors.wood),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// كارت طلب غني - صورة مصغّرة، اسم العميل والصنف، تاريخ التسليم، المتبقي،
/// شارة الحالة الملوّنة (مع اكتشاف "متأخر" فعليًا من تاريخ التسليم الحقيقي
/// مش نص متخزّن)، شريط تقدّم حسب مرحلة التصنيع، وزرار اتصال بالعميل
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final String? phone;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.phone, required this.onTap});

  static const _stages = ['جاري التجهيز', 'قيد التنفيذ', 'جاهز للتسليم', 'تم التسليم'];

  (Color, String) _statusVisual() {
    final isOverdue = order.status != 'تم التسليم' && order.deliveryDate.isBefore(DateTime.now());
    if (isOverdue) return (AppColors.danger, 'متأخر');
    switch (order.status) {
      case 'جاهز للتسليم':
        return (AppColors.navy, order.status);
      case 'تم التسليم':
        return (AppColors.success, order.status);
      default:
        return (AppColors.warning, order.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = _statusVisual();
    final stageIndex = _stages.indexOf(order.status);
    final progress = stageIndex == -1 ? 0.0 : (stageIndex + 1) / _stages.length;
    final fmt = NumberFormat.decimalPattern('ar');

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: order.images.isNotEmpty
                    ? Image.network(
                        order.images.first,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackThumb(context),
                      )
                    : _fallbackThumb(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${order.customerName} - ${order.itemType}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
                          child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'تسليم ${DateFormat('d MMM', 'ar').format(order.deliveryDate)}'
                      '${order.remainingAmount > 0 ? ' · متبقي ${fmt.format(order.remainingAmount)} ج.م' : ''}',
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: statusColor.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation(statusColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: phone == null || phone!.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: phone!));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('اتنسخ رقم $phone')));
                      },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.14), shape: BoxShape.circle),
                  child: const Icon(Icons.phone_rounded, size: 15, color: AppColors.success),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackThumb(BuildContext context) => Container(
        width: 48,
        height: 48,
        color: Theme.of(context).dividerColor.withOpacity(0.15),
        child: const Icon(Icons.chair_rounded, color: Colors.grey),
      );
}
