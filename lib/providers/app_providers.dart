import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/expense_model.dart';
import '../models/user_account_model.dart';
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

/// كل الدفعات في كل الطلبات - أساس رسم الإيرادات الشهرية بالداشبورد
final transactionsStreamProvider = StreamProvider((ref) {
  return ref.watch(firebaseServiceProvider).streamTransactions();
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

  DashboardStats({
    required this.totalRevenue,
    required this.totalDebts,
    required this.totalExpenses,
    required this.netProfit,
    required this.pendingDeliveriesThisWeek,
  });
}

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final orders = ref.watch(ordersStreamProvider).value ?? [];
  final expenses = ref.watch(expensesStreamProvider).value ?? [];

  final totalRevenue = orders.fold<double>(0, (sum, o) => sum + o.totalPaid);
  final totalDebts = orders.fold<double>(0, (sum, o) => sum + o.remainingAmount);
  final totalExpenses = expenses.fold<double>(0, (sum, e) => sum + e.amount);
  final netProfit = totalRevenue - totalExpenses;

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
  );
});

final workerAdvancesProvider = Provider<Map<String, double>>((ref) {
  final expenses = ref.watch(expensesStreamProvider).value ?? [];
  final Map<String, double> totals = {};
  for (final e in expenses.where((e) => e.category == 'wages' && e.workerName != null)) {
    totals[e.workerName!] = (totals[e.workerName!] ?? 0) + e.amount;
  }
  return totals;
});

/// نقطة واحدة في رسم الإيرادات الشهرية (آخر 6 شهور)
class MonthlyRevenuePoint {
  final String label;
  final double amount;
  MonthlyRevenuePoint({required this.label, required this.amount});
}

final monthlyRevenueProvider = Provider<List<MonthlyRevenuePoint>>((ref) {
  final transactions = ref.watch(transactionsStreamProvider).value ?? [];
  final now = DateTime.now();
  final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1));

  return months.map((monthStart) {
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
    final total = transactions
        .where((t) =>
            !t.paymentDate.isBefore(monthStart) && t.paymentDate.isBefore(monthEnd))
        .fold<double>(0, (sum, t) => sum + t.amountPaid);
    return MonthlyRevenuePoint(label: DateFormat('MMM', 'ar').format(monthStart), amount: total);
  }).toList();
});

/// توزيع إجمالي قيمة الطلبات حسب نوع الصنف - لرسم Pie Chart بالداشبورد
final itemTypeBreakdownProvider = Provider<Map<String, double>>((ref) {
  final orders = ref.watch(ordersStreamProvider).value ?? [];
  final Map<String, double> totals = {};
  for (final o in orders) {
    totals[o.itemType] = (totals[o.itemType] ?? 0) + o.totalAmount;
  }
  return totals;
});
