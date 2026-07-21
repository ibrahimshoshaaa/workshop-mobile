import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import '../../providers/app_providers.dart';
import '../../core/auth_state.dart';
import '../../widgets/privacy_blur.dart';
import '../../local/local_cache_service.dart';
import '../../services/notification_service.dart';
import '../../models/order_model.dart';
import '../../models/customer_model.dart';
import '../../models/worker_model.dart';
import '../../providers/privacy_provider.dart';

/// ألوان الداشبورد الجديدة - هوية بصرية مستقلة (دارك، فاخرة) خاصة بالشاشة
/// دي بس، وما بتأثرش على باقي شاشات التطبيق اللي لسه شغالة بـ AppTheme العادي
class _P {
  _P._();
  static const bg = Color(0xFF0A0A0D);
  static const surface1 = Color(0xFF15151B);
  static const surface1Border = Color(0x0FFFFFFF);
  static const heroBorder = Color(0x29E3B053);
  static const gold = Color(0xFFE3B053);
  static const goldSoft = Color(0x24E3B053);
  static const teal = Color(0xFF33D399);
  static const tealSoft = Color(0x2433D399);
  static const textPrimary = Color(0xFFF4F3F1);
  static const textSecondary = Color(0xFF9B99A3);
  static const textMuted = Color(0xFF5E5C68);
  static const y = Color(0xFFF0A93B);
  static const ySoft = Color(0x24F0A93B);
  static const b = Color(0xFF4C8DFF);
  static const bSoft = Color(0x244C8DFF);
  static const g = Color(0xFF34D399);
  static const gSoft = Color(0x2434D399);
  static const r = Color(0xFFFF5C5C);
  static const rSoft = Color(0x24FF5C5C);
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static bool _notificationPermissionRequested = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final orders = ref.watch(ordersStreamProvider).value ?? [];
    final customers = ref.watch(customersStreamProvider).value ?? [];
    final dueWorkers = AuthState.can('workers') ? ref.watch(workersDueTodayProvider) : <WorkerModel>[];
    final upcomingDeliveries = ref.watch(upcomingDeliveriesProvider);

    // تجديد تنبيه المديونيات كل ما بيانات المديونيات تتغيّر
    ref.listen<AsyncValue<List<OrderModel>>>(debtorOrdersStreamProvider, (previous, next) {
      final debtors = next.value ?? [];
      final total = debtors.fold<double>(0, (sum, o) => sum + o.remainingAmount);
      NotificationService.instance.scheduleDebtReminder(total, debtors.length);
    });

    // طلب إذن الإشعارات - نفس المنطق القديم بالظبط (مرة واحدة بس في الجلسة،
    // وبعد ما الداشبورد يستقر شوية)
    if (!_notificationPermissionRequested) {
      _notificationPermissionRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 800), () {
          NotificationService.instance.requestPermission();
        });
      });
    }

    // "الطلبات الحالية": أقرب الطلبات اللي لسه ما اتسلمتش (متأخرة أو جاية)،
    // مرتبة بحيث المتأخر/الأقرب تسليمًا يظهر الأول
    final activeOrders = orders.where((o) => o.status != 'تم التسليم').toList()
      ..sort((a, b) => a.deliveryDate.compareTo(b.deliveryDate));
    final displayOrders = activeOrders.take(5).toList();

    final isPrivate = ref.watch(privacyModeProvider);

    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _P.gold,
          backgroundColor: _P.surface1,
          onRefresh: () async => ref.invalidate(ordersStreamProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
            children: [
              _Header(
                isPrivate: isPrivate,
                onTogglePrivacy: () => ref.read(privacyModeProvider.notifier).toggle(),
                onSettings: AuthState.isAdmin ? () => context.push('/settings') : null,
                onLogout: () => _confirmLogout(context),
              ),
              const SizedBox(height: 18),
              _HeroCashCard(
                total: stats.cashAvailable + stats.instapayAvailable,
                cash: stats.cashAvailable,
                instapay: stats.instapayAvailable,
                netProfit: stats.netProfit,
                onInstapayTap: () => _showCashTransferDialog(context, ref, stats.instapayAvailable),
              ),
              if (dueWorkers.isNotEmpty) ...[
                const SizedBox(height: 14),
                _PaydayBanner(
                  names: dueWorkers.map((w) => w.name).join('، '),
                  onTap: () => context.push('/workers'),
                ),
              ],
              const _SectionTitle('نظرة عامة'),
              const SizedBox(height: 12),
              _StatsGrid2x2(
                revenue: stats.totalRevenue,
                expenses: stats.totalExpenses,
                debts: stats.totalDebts,
                payables: stats.totalWorkshopDebts,
                onRevenueTap: () => context.push('/reports/revenue-detail'),
                onDebtsTap: () => context.push('/debts'),
                onPayablesTap: () => context.push('/workshop-debts'),
              ),
              const _SectionTitle('إجراءات سريعة'),
              const SizedBox(height: 12),
              _QuickActionsRow(
                onAddOrder: () => context.push('/orders/add'),
                onAddCustomer: () => context.push('/customers/add'),
                onRegisterPayment: () => context.push('/orders'),
                onDeliverOrder: () => context.push('/orders'),
              ),
              _SectionTitle(
                'الطلبات الحالية',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (upcomingDeliveries.isNotEmpty)
                      IconButton(
                        tooltip: 'مشاركة التسليمات القريبة',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.share_rounded, color: _P.teal, size: 19),
                        onPressed: () => _shareUpcomingDeliveries(upcomingDeliveries),
                      ),
                    GestureDetector(
                      onTap: () => context.push('/orders'),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('عرض الكل', style: TextStyle(color: _P.gold, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (displayOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('لا توجد طلبات حالية', style: TextStyle(color: _P.textMuted)),
                )
              else
                ...displayOrders.map((o) {
                  final customer = customers.where((c) => c.id == o.customerId).firstOrNull;
                  return _OrderCard(order: o, customer: customer);
                }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
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
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
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

/// صف الترحيب + أزرار الخصوصية/الإعدادات/الخروج - بديل الـ AppBar التقليدي
class _Header extends StatelessWidget {
  final bool isPrivate;
  final VoidCallback onTogglePrivacy;
  final VoidCallback? onSettings;
  final VoidCallback onLogout;

  const _Header({
    required this.isPrivate,
    required this.onTogglePrivacy,
    required this.onSettings,
    required this.onLogout,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 17) return 'مساء النور';
    return 'مساء الخير';
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthState.currentUsername ?? '';
    final dateStr = DateFormat('EEEE، d MMMM', 'ar').format(DateTime.now());

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? _greeting : '$_greeting، $name',
                style: const TextStyle(color: _P.textPrimary, fontSize: 21, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(dateStr, style: const TextStyle(color: _P.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        _HeaderIconButton(
          icon: isPrivate ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          onTap: onTogglePrivacy,
        ),
        if (onSettings != null) ...[
          const SizedBox(width: 8),
          _HeaderIconButton(icon: Icons.settings_rounded, onTap: onSettings!),
        ],
        const SizedBox(width: 8),
        _HeaderIconButton(icon: Icons.logout_rounded, onTap: onLogout),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _P.surface1,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _P.surface1Border),
          ),
          child: Icon(icon, color: _P.textPrimary, size: 19),
        ),
      ),
    );
  }
}

/// كارت الكاش الرئيسي (Hero) - أكبر عنصر في الشاشة، بيجمع الكاش +
/// إنستاباي في رقم واحد واضح، وتحته تفصيل كل مصدر على حدة
class _HeroCashCard extends StatelessWidget {
  final double total;
  final double cash;
  final double instapay;
  final double netProfit;
  final VoidCallback onInstapayTap;

  const _HeroCashCard({
    required this.total,
    required this.cash,
    required this.instapay,
    required this.netProfit,
    required this.onInstapayTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 0);
    final profitUp = netProfit >= 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _P.heroBorder),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1D1B17), Color(0xFF121214)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 16)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              _Lamp(),
              SizedBox(width: 8),
              Text('الرصيد المتاح اليوم', style: TextStyle(color: _P.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          PrivacyBlur(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                formatter.format(total),
                style: const TextStyle(color: _P.textPrimary, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: profitUp ? _P.gSoft : _P.rSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(profitUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: profitUp ? _P.g : _P.r, size: 15),
                const SizedBox(width: 4),
                PrivacyBlur(
                  child: Text(
                    'صافي الربح ${formatter.format(netProfit.abs())}',
                    style: TextStyle(color: profitUp ? _P.g : _P.r, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _HeroSubRow(label: 'نقدي', value: cash, formatter: formatter)),
              Container(width: 1, height: 30, color: _P.surface1Border),
              Expanded(
                child: InkWell(
                  onTap: onInstapayTap,
                  borderRadius: BorderRadius.circular(10),
                  child: _HeroSubRow(label: 'إنستاباي', value: instapay, formatter: formatter, tappable: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Lamp extends StatelessWidget {
  const _Lamp();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: _P.teal,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: _P.teal.withValues(alpha: 0.6), blurRadius: 6)],
      ),
    );
  }
}

class _HeroSubRow extends StatelessWidget {
  final String label;
  final double value;
  final NumberFormat formatter;
  final bool tappable;
  const _HeroSubRow({required this.label, required this.value, required this.formatter, this.tappable = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: _P.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                PrivacyBlur(
                  child: Text(
                    formatter.format(value),
                    style: const TextStyle(color: _P.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (tappable) const Icon(Icons.chevron_left_rounded, color: _P.textMuted, size: 18),
        ],
      ),
    );
  }
}

class _PaydayBanner extends StatelessWidget {
  final String names;
  final VoidCallback onTap;
  const _PaydayBanner({required this.names, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _P.ySoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: _P.y, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('النهاردة يوم القبض الأسبوعي',
                        style: TextStyle(color: _P.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('مستني تأكيد الدفع: $names',
                        style: const TextStyle(color: _P.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: _P.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionTitle(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: _P.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// شبكة الإحصائيات 2×2 - نفس بيانات الداشبورد القديمة (الإيرادات،
/// المصروفات، مديونيات العملاء، مستحقات الورشة) في تصميم مضغوط
class _StatsGrid2x2 extends StatelessWidget {
  final double revenue;
  final double expenses;
  final double debts;
  final double payables;
  final VoidCallback onRevenueTap;
  final VoidCallback onDebtsTap;
  final VoidCallback onPayablesTap;

  const _StatsGrid2x2({
    required this.revenue,
    required this.expenses,
    required this.debts,
    required this.payables,
    required this.onRevenueTap,
    required this.onDebtsTap,
    required this.onPayablesTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.trending_up_rounded,
                color: _P.teal,
                colorSoft: _P.tealSoft,
                label: 'إجمالي الإيرادات',
                value: revenue,
                onTap: onRevenueTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.receipt_long_rounded,
                color: _P.r,
                colorSoft: _P.rSoft,
                label: 'إجمالي المصروفات',
                value: expenses,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.groups_rounded,
                color: _P.y,
                colorSoft: _P.ySoft,
                label: 'مديونيات العملاء',
                value: debts,
                onTap: onDebtsTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.storefront_rounded,
                color: _P.gold,
                colorSoft: _P.goldSoft,
                label: 'مستحقات الورشة',
                value: payables,
                onTap: onPayablesTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color colorSoft;
  final String label;
  final double value;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.colorSoft,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 0);
    return Material(
      color: _P.surface1,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _P.surface1Border),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: colorSoft, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(height: 12),
              PrivacyBlur(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    formatter.format(value),
                    style: const TextStyle(color: _P.textPrimary, fontSize: 19, fontWeight: FontWeight.w800),
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: _P.textSecondary, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onAddOrder;
  final VoidCallback onAddCustomer;
  final VoidCallback onRegisterPayment;
  final VoidCallback onDeliverOrder;

  const _QuickActionsRow({
    required this.onAddOrder,
    required this.onAddCustomer,
    required this.onRegisterPayment,
    required this.onDeliverOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ActionButton(icon: Icons.add_rounded, label: 'إضافة طلب', onTap: onAddOrder)),
        const SizedBox(width: 10),
        Expanded(child: _ActionButton(icon: Icons.person_add_alt_1_rounded, label: 'إضافة عميل', onTap: onAddCustomer)),
        const SizedBox(width: 10),
        Expanded(child: _ActionButton(icon: Icons.payments_rounded, label: 'تسجيل دفعة', onTap: onRegisterPayment)),
        const SizedBox(width: 10),
        Expanded(child: _ActionButton(icon: Icons.local_shipping_rounded, label: 'تسليم طلب', onTap: onDeliverOrder)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _P.surface1,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _P.surface1Border),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: _P.goldSoft, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Icon(icon, color: _P.gold, size: 19),
              ),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(color: _P.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// كارت الطلب - صورة مصغّرة، اسم العميل والمنتج، تاريخ التسليم، المتبقي،
/// شريط تقدّم حسب الحالة، بادچ ملوّن، وزر اتصال مباشر بالعميل
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final CustomerModel? customer;
  const _OrderCard({required this.order, this.customer});

  bool get _isOverdue {
    if (order.status == 'تم التسليم') return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final delivery = DateTime(order.deliveryDate.year, order.deliveryDate.month, order.deliveryDate.day);
    return delivery.isBefore(todayOnly);
  }

  Color get _statusColor {
    if (_isOverdue) return _P.r;
    switch (order.status) {
      case 'جاهز للتسليم':
        return _P.b;
      case 'تم التسليم':
        return _P.g;
      default:
        return _P.y;
    }
  }

  Color get _statusColorSoft {
    if (_isOverdue) return _P.rSoft;
    switch (order.status) {
      case 'جاهز للتسليم':
        return _P.bSoft;
      case 'تم التسليم':
        return _P.gSoft;
      default:
        return _P.ySoft;
    }
  }

  String get _statusLabel => _isOverdue ? 'متأخر' : order.status;

  double get _progress {
    switch (order.status) {
      case 'قيد التنفيذ':
        return 0.55;
      case 'جاهز للتسليم':
        return 0.85;
      case 'تم التسليم':
        return 1.0;
      default:
        return 0.25;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'ar_EG', symbol: 'ج.م', decimalDigits: 0);
    final dateStr = DateFormat('d MMM', 'ar').format(order.deliveryDate);
    final phone = customer?.phone ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _P.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.surface1Border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(imageUrl: order.images.isNotEmpty ? order.images.first : null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.customerName,
                        style: const TextStyle(color: _P.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(order.itemType,
                        style: const TextStyle(color: _P.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _statusColorSoft, borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel, style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(color: _P.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
                    children: [
                      TextSpan(text: 'تسليم: $dateStr  ·  متبقي '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: PrivacyBlur(
                          child: Text(
                            order.remainingAmount > 0 ? formatter.format(order.remainingAmount) : 'مسدد',
                            style: TextStyle(
                              color: order.remainingAmount > 0 ? _P.textPrimary : _P.g,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _CallButton(phone: phone),
            ],
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? imageUrl;
  const _Thumb({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 52,
        height: 52,
        color: _P.goldSoft,
        child: imageUrl == null
            ? const Icon(Icons.chair_alt_rounded, color: _P.gold, size: 24)
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(Icons.chair_alt_rounded, color: _P.gold, size: 24),
                placeholder: (context, url) => const Icon(Icons.chair_alt_rounded, color: _P.gold, size: 24),
              ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final String phone;
  const _CallButton({required this.phone});

  Future<void> _call() async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = phone.isNotEmpty;
    return Material(
      color: enabled ? _P.tealSoft : _P.surface1Border,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? _call : null,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(Icons.call_rounded, color: enabled ? _P.teal : _P.textMuted, size: 16),
        ),
      ),
    );
  }
}
