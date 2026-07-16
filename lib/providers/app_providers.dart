import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/expense_model.dart';
import '../models/user_account_model.dart';
import '../models/material_item_model.dart';
import '../models/worker_model.dart';
import '../models/workshop_debt_model.dart';
import '../services/firebase_service.dart';
import '../local/local_cache_service.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService.instance);

// ---------------- Streams (Cache-then-Network) ----------------

final customersStreamProvider = StreamProvider<List<CustomerModel>>((ref) async* {
  final cache = LocalCacheService.instance;
  final cached = cache.readAll(LocalCacheService.customersBox);
  if (cached.isNotEmpty) {
    yield cached.entries.map((e) => CustomerModel.fromMap(e.key, e.value)).toList();
  }
  await for (final list in ref.watch(firebaseServiceProvider).streamCustomers()) {
    unawaited(cache.replaceAll(
      LocalCacheService.customersBox,
      {for (final c in list) c.id: c.toMap()},
    ));
    yield list;
  }
});

final ordersStreamProvider = StreamProvider<List<OrderModel>>((ref) async* {
  final cache = LocalCacheService.instance;
  final cached = cache.readAll(LocalCacheService.ordersBox);
  if (cached.isNotEmpty) {
    yield cached.entries.map((e) => OrderModel.fromMap(e.key, e.value)).toList();
  }
  await for (final list in ref.watch(firebaseServiceProvider).streamOrders()) {
    unawaited(cache.replaceAll(
      LocalCacheService.ordersBox,
      {for (final o in list) o.id: o.toMap()},
    ));
    yield list;
  }
});

final debtorOrdersStreamProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(ordersStreamProvider.stream).map(
        (orders) => orders.where((o) => o.remainingAmount > 0).toList()
          ..sort((a, b) => b.remainingAmount.compareTo(a.remainingAmount)),
      );
});

final expensesStreamProvider = StreamProvider<List<ExpenseModel>>((ref) async* {
  final cache = LocalCacheService.instance;
  final cached = cache.readAll(LocalCacheService.expensesBox);
  if (cached.isNotEmpty) {
    yield cached.entries.map((e) => ExpenseModel.fromMap(e.key, e.value)).toList();
  }
  await for (final list in ref.watch(firebaseServiceProvider).streamExpenses()) {
    unawaited(cache.replaceAll(
      LocalCacheService.expensesBox,
      {for (final e in list) e.id: e.toMap()},
    ));
    yield list;
  }
});

final ordersForCustomerProvider =
    StreamProvider.family<List<OrderModel>, String>((ref, customerId) {
  return ref.watch(firebaseServiceProvider).streamOrdersForCustomer(customerId);
});

final appUsersStreamProvider = StreamProvider<List<UserAccountModel>>((ref) {
  return ref.watch(firebaseServiceProvider).streamUsers();
});

final transactionsStreamProvider = StreamProvider((ref) {
  return ref.watch(firebaseServiceProvider).streamTransactions();
});

final materialsStreamProvider = StreamProvider<List<MaterialItemModel>>((ref) {
  return ref.watch(firebaseServiceProvider).streamMaterials();
});

/// الخامات اللي وصلت للحد الأدنى أو أقل - أساس تنبيه المخزون
final lowStockMaterialsProvider = Provider<List<MaterialItemModel>>((ref) {
  final materials = ref.watch(materialsStreamProvider).value ?? [];
  return materials.where((m) => m.isLow).toList();
});

final workshopDebtsStreamProvider = StreamProvider<List<WorkshopDebtModel>>((ref) {
  return ref.watch(firebaseServiceProvider).streamWorkshopDebts();
});

final unpaidWorkshopDebtsProvider = Provider<List<WorkshopDebtModel>>((ref) {
  final debts = ref.watch(workshopDebtsStreamProvider).value ?? [];
  return debts.where((d) => d.remainingAmount > 0).toList()
    ..sort((a, b) => b.remainingAmount.compareTo(a.remainingAmount));
});

final workersStreamProvider = StreamProvider<List<WorkerModel>>((ref) {
  return ref.watch(firebaseServiceProvider).streamWorkers();
});

final workerPaymentsStreamProvider = StreamProvider((ref) {
  return ref.watch(firebaseServiceProvider).streamWorkerPayments();
});

final workerPaymentsForWorkerProvider = Provider.family((ref, String workerId) {
  final all = ref.watch(workerPaymentsStreamProvider).value ?? [];
  return all.where((p) => p.workerId == workerId).toList()
    ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
});

/// بيحسب بداية دورة الاستحقاق الحالية (منتصف الليل) لعامل معيّن حسب نوع
/// مرتبه: يومي = النهاردة، أسبوعي = آخر (أو نفس) يوم القبض المحدد،
/// شهري = أول يوم في الشهر الحالي - نفس منطق الديسكتوب بالظبط
DateTime workerPeriodAnchor(WorkerModel worker, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  switch (worker.salaryType) {
    case 'weekly':
      final diff = (now.weekday - worker.payWeekday + 7) % 7;
      return today.subtract(Duration(days: diff));
    case 'monthly':
      return DateTime(now.year, now.month, 1);
    default: // daily
      return today;
  }
}

bool isWorkerPaidForCurrentPeriod(WorkerModel worker, List payments, DateTime now) {
  final anchor = workerPeriodAnchor(worker, now);
  return payments.any((p) => p.workerId == worker.id && p.periodStart.isAtSameMomentAs(anchor));
}

/// العمال الأسبوعيين اللي موعد قبضهم النهاردة بالظبط ولسه ما اتأكدش
/// دفعهم - نفس البانر الموجود في الديسكتوب
final workersDueTodayProvider = Provider<List<WorkerModel>>((ref) {
  final workers = ref.watch(workersStreamProvider).value ?? [];
  final payments = ref.watch(workerPaymentsStreamProvider).value ?? [];
  final now = DateTime.now();
  return workers.where((w) {
    if (w.salaryType != 'weekly' || w.payWeekday != now.weekday) return false;
    return !isWorkerPaidForCurrentPeriod(w, payments, now);
  }).toList();
});

// ---------------- Filters (حالة الطلب / بحث) ----------------

final orderStatusFilterProvider = StateProvider<String?>((ref) => null);
final orderSearchQueryProvider = StateProvider<String>((ref) => '');
final customerSearchQueryProvider = StateProvider<String>((ref) => '');
final expenseCategoryFilterProvider = StateProvider<String?>((ref) => null);

final filteredOrdersProvider = Provider<List<OrderModel>>((ref) {
  final orders = ref.watch(ordersStreamProvider).value ?? [];
  final status = ref.watch(orderStatusFilterProvider);
  final query = ref.watch(orderSearchQueryProvider).trim();

  var result = orders;
  if (status != null && status.isNotEmpty) {
    result = result.where((o) => o.status == status).toList();
  }
  if (query.isNotEmpty) {
    result = result.where((o) => o.customerName.contains(query) || o.itemType.contains(query)).toList();
  }
  return result;
});

final filteredCustomersProvider = Provider<List<CustomerModel>>((ref) {
  final customers = ref.watch(customersStreamProvider).value ?? [];
  final query = ref.watch(customerSearchQueryProvider).trim();
  if (query.isEmpty) return customers;
  return customers
      .where((c) => c.name.contains(query) || c.phone.contains(query))
      .toList();
});

final filteredExpensesProvider = Provider<List<ExpenseModel>>((ref) {
  final expenses = ref.watch(expensesStreamProvider).value ?? [];
  final category = ref.watch(expenseCategoryFilterProvider);
  if (category == null || category.isEmpty) return expenses;
  return expenses.where((e) => e.category == category).toList();
});

// ---------------- Dashboard Analytics ----------------

class DashboardStats {
  final double totalRevenue;
  final double totalDebts;
  final double totalExpenses;
  final double netProfit;
  final int pendingDeliveriesThisWeek;
  /// تفنيط "المبلغ المتاح" حسب مصدره: كاش/إنستاباي - كل واحد فيهم = ما
  /// دخل من دفعات بنفس الطريقة ناقص المصروفات اللي خرجت من نفس المصدر
  final double cashAvailable;
  final double instapayAvailable;
  final double totalWorkshopDebts;

  DashboardStats({
    required this.totalRevenue,
    required this.totalDebts,
    required this.totalExpenses,
    required this.netProfit,
    required this.pendingDeliveriesThisWeek,
    required this.cashAvailable,
    required this.instapayAvailable,
    required this.totalWorkshopDebts,
  });
}

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final orders = ref.watch(ordersStreamProvider).value ?? [];
  final expenses = ref.watch(expensesStreamProvider).value ?? [];
  final transactions = ref.watch(transactionsStreamProvider).value ?? [];
  final workshopDebts = ref.watch(workshopDebtsStreamProvider).value ?? [];

  final totalRevenue = orders.fold<double>(0, (sum, o) => sum + o.totalPaid);
  final totalDebts = orders.fold<double>(0, (sum, o) => sum + o.remainingAmount);
  final totalExpenses = expenses.fold<double>(0, (sum, e) => sum + e.amount);
  final netProfit = totalRevenue - totalExpenses;
  final totalWorkshopDebts = workshopDebts.fold<double>(0, (sum, d) => sum + d.remainingAmount);

  // بنستبعد أي دفعة مرتبطة بطلب اتحذف - نفس منطق الديسكتوب بالظبط
  final liveOrderIds = orders.map((o) => o.id).toSet();
  double revenueByMethod(String method) => transactions
      .where((t) => t.paymentMethod == method && liveOrderIds.contains(t.orderId))
      .fold<double>(0, (sum, t) => sum + t.amountPaid);
  double expensesByMethod(String method) =>
      expenses.where((e) => e.paymentMethod == method).fold<double>(0, (sum, e) => sum + e.amount);

  final cashAvailable = revenueByMethod('cash') - expensesByMethod('cash');
  final instapayAvailable = revenueByMethod('instapay') - expensesByMethod('instapay');

  final now = DateTime.now();
  final weekFromNow = now.add(const Duration(days: 7));
  final pendingThisWeek = orders
      .where((o) =>
          o.status != 'تم التسليم' &&
          o.deliveryDate.isAfter(now.subtract(const Duration(days: 1))) &&
          o.deliveryDate.isBefore(weekFromNow))
      .length;

  return DashboardStats(
    totalRevenue: totalRevenue,
    totalDebts: totalDebts,
    totalExpenses: totalExpenses,
    netProfit: netProfit,
    pendingDeliveriesThisWeek: pendingThisWeek,
    cashAvailable: cashAvailable,
    instapayAvailable: instapayAvailable,
    totalWorkshopDebts: totalWorkshopDebts,
  );
});

/// الطلبات اللي معاد تسليمها خلال الأسبوع الجاي (من دلوقتي لحد بعد 7 أيام)
/// ولسه ماتسلمتش - نفس منطق بانر "التسليمات القادمة" في الديسكتوب
final upcomingDeliveriesProvider = Provider<List<OrderModel>>((ref) {
  final orders = ref.watch(ordersStreamProvider).value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekAhead = today.add(const Duration(days: 7));
  return orders.where((o) {
    if (o.status == 'تم التسليم') return false;
    final delivery = DateTime(o.deliveryDate.year, o.deliveryDate.month, o.deliveryDate.day);
    return !delivery.isBefore(today) && delivery.isBefore(weekAhead);
  }).toList()
    ..sort((a, b) => a.deliveryDate.compareTo(b.deliveryDate));
});

final workerAdvancesProvider = Provider<Map<String, double>>((ref) {
  final expenses = ref.watch(expensesStreamProvider).value ?? [];
  final Map<String, double> totals = {};
  for (final e in expenses.where((e) => e.category == 'wages' && e.workerName != null)) {
    totals[e.workerName!] = (totals[e.workerName!] ?? 0) + e.amount;
  }
  return totals;
});
