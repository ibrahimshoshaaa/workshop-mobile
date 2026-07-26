import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import 'app_providers.dart';

/// نوع النشاط - بيحدد الأيقونة واللون في الشاشة
enum ActivityKind {
  newOrder,
  orderPayment,
  customerRefund,
  expense,
  newCustomer,
  workerPayment,
  cashTransfer,
  workshopDebt,
}

/// عنصر نشاط واحد في السجل الموحّد - بيتبني من كل الداتا سترييمز الموجودة
/// أصلاً (عملاء/طلبات/دفعات/مصروفات/مرتبات/تحويلات/ديون ورشة). البيانات دي
/// كلها جاية من فايربيز اللي التطبيقين (موبايل وديسكتوب) بيكتبوا عليه، يعني
/// أي حاجة تتعمل من أي جهاز هتظهر هنا تلقائيًا - مفيش حاجة خاصة بالموبايل بس
class ActivityItem {
  final DateTime time;
  final ActivityKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const ActivityItem({
    required this.time,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

final activityLogProvider = Provider<List<ActivityItem>>((ref) {
  final orders = ref.watch(ordersStreamProvider).value ?? [];
  final transactions = ref.watch(transactionsStreamProvider).value ?? [];
  final expenses = ref.watch(expensesStreamProvider).value ?? [];
  final customers = ref.watch(customersStreamProvider).value ?? [];
  final workerPayments = ref.watch(workerPaymentsStreamProvider).value ?? [];
  final cashTransfers = ref.watch(cashTransfersStreamProvider).value ?? [];
  final workshopDebts = ref.watch(workshopDebtsStreamProvider).value ?? [];

  final items = <ActivityItem>[];

  for (final o in orders) {
    items.add(ActivityItem(
      time: o.createdAt,
      kind: ActivityKind.newOrder,
      title: 'تم تسجيل طلب جديد',
      subtitle: '${o.customerName} - ${o.itemType}',
      icon: Icons.checkroom_rounded,
      color: AppColors.navy,
    ));
  }
  for (final t in transactions) {
    if (t.paymentType == AppConstants.paymentRefund) {
      // ده مش "دفعة من عميل" - ده استرجاع فلوس لعميل دفع زيادة عن الاتفاق
      // بعد ما اتعدّل (شوف payWorkshopDebt في firebase_service.dart)
      final order = orders.where((o) => o.id == t.orderId).firstOrNull;
      items.add(ActivityItem(
        time: t.paymentDate,
        kind: ActivityKind.customerRefund,
        title: 'تم استرجاع فلوس لعميل',
        subtitle: '${order?.customerName ?? 'عميل'} - -${t.amountPaid.abs().toStringAsFixed(0)} ج.م',
        icon: Icons.undo_rounded,
        color: AppColors.wood,
      ));
    } else {
      items.add(ActivityItem(
        time: t.paymentDate,
        kind: ActivityKind.orderPayment,
        title: 'تم تسجيل دفعة من عميل',
        subtitle: '+${t.amountPaid.toStringAsFixed(0)} ج.م',
        icon: Icons.trending_up_rounded,
        color: AppColors.success,
      ));
    }
  }
  for (final e in expenses) {
    items.add(ActivityItem(
      time: e.date,
      kind: ActivityKind.expense,
      title: 'تم تسجيل مصروف',
      subtitle: '-${e.amount.toStringAsFixed(0)} ج.م'
          '${e.description.isNotEmpty ? ' - ${e.description}' : ''}',
      icon: Icons.receipt_long_rounded,
      color: AppColors.danger,
    ));
  }
  for (final c in customers) {
    items.add(ActivityItem(
      time: c.createdAt,
      kind: ActivityKind.newCustomer,
      title: 'تم إضافة عميل جديد',
      subtitle: c.name,
      icon: Icons.person_add_alt_1_rounded,
      color: AppColors.amber,
    ));
  }
  for (final p in workerPayments) {
    items.add(ActivityItem(
      time: p.paymentDate,
      kind: ActivityKind.workerPayment,
      title: 'تم صرف مرتب/سلفة',
      subtitle: '${p.workerName} - ${p.amount.toStringAsFixed(0)} ج.م',
      icon: Icons.engineering_rounded,
      color: AppColors.warning,
    ));
  }
  for (final ct in cashTransfers) {
    items.add(ActivityItem(
      time: ct.date,
      kind: ActivityKind.cashTransfer,
      title: 'تحويل بين الكاش والإنستاباي',
      subtitle: '${ct.amount.toStringAsFixed(0)} ج.م'
          '${ct.note.isNotEmpty ? ' - ${ct.note}' : ''}',
      icon: Icons.swap_horiz_rounded,
      color: AppColors.wood,
    ));
  }
  for (final d in workshopDebts) {
    items.add(ActivityItem(
      time: d.createdAt,
      kind: ActivityKind.workshopDebt,
      title: 'تم تسجيل دين على الورشة',
      subtitle: '${d.creditorName} - ${d.totalAmount.toStringAsFixed(0)} ج.م',
      icon: Icons.store_rounded,
      color: AppColors.danger,
    ));
  }

  items.sort((a, b) => b.time.compareTo(a.time));
  return items;
});
