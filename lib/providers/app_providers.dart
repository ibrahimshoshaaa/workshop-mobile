import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/expense_model.dart';
import '../services/firebase_service.dart';
import '../local/local_cache_service.dart';
import '../models/user_account_model.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService.instance);

// ---------------- Streams (Cache-then-Network) ----------------
// كل ستريم بيعرض أول حاجة النسخة المخزنة محليًا في Hive فورًا (لو موجودة)
// عشان الشاشة متفضلش فاضية وقت فتح التطبيق أو لو النت بطيء، وبعدين يتابع
// على آخر تحديثات Realtime Database الحية، وفي نفس الوقت بيحدّث نسخة الكاش
// بأحدث بيانات (Write-Through) استعدادًا لمرة الفتح الجاية.

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
  // مبنية فوق ordersStreamProvider نفسه (بما فيه الكاش) بدل ما تعمل اتصال منفصل
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
// ---------------- Filters (حالة الطلب / بحث) ----------------

final orderStatusFilterProvider = StateProvider<String?>((ref) => null);
final customerSearchQueryProvider = StateProvider<String>((ref) => '');
final expenseCategoryFilterProvider = StateProvider<String?>((ref) => null);
final orderSearchQueryProvider = StateProvider<String>((ref) => '');

/// الطلبات بعد تطبيق فلتر الحالة
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
/// العملاء بعد تطبيق البحث بالاسم أو رقم الهاتف
final filteredCustomersProvider = Provider<List<CustomerModel>>((ref) {
  final customers = ref.watch(customersStreamProvider).value ?? [];
  final query = ref.watch(customerSearchQueryProvider).trim();
  if (query.isEmpty) return customers;
  return customers
      .where((c) => c.name.contains(query) || c.phone.contains(query))
      .toList();
});

/// المصروفات بعد فلتر الفئة
final filteredExpensesProvider = Provider<List<ExpenseModel>>((ref) {
  final expenses = ref.watch(expensesStreamProvider).value ?? [];
  final category = ref.watch(expenseCategoryFilterProvider);
  if (category == null || category.isEmpty) return expenses;
  return expenses.where((e) => e.category == category).toList();
});

// ---------------- Dashboard Analytics ----------------

class DashboardStats {
  final double totalRevenue; // إجمالي المحصل من العربون والدفعات
  final double totalDebts; // إجمالي المديونيات المستحقة
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

/// إجمالي السحبيات لكل صنايعي (لصفحة أجور الصنايعية)
final workerAdvancesProvider = Provider<Map<String, double>>((ref) {
  final expenses = ref.watch(expensesStreamProvider).value ?? [];
  final Map<String, double> totals = {};
  for (final e in expenses.where((e) => e.category == 'wages' && e.workerName != null)) {
    totals[e.workerName!] = (totals[e.workerName!] ?? 0) + e.amount;
  }
  return totals;
});
