import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'cloudinary_service.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/expense_model.dart';
import '../models/user_account_model.dart';
import '../models/material_item_model.dart';
import '../models/worker_model.dart';
import '../models/workshop_debt_model.dart';

class FirebaseService {
  FirebaseService._() {
    _customers.keepSynced(true);
    _orders.keepSynced(true);
    _transactions.keepSynced(true);
    _expenses.keepSynced(true);
    _users.keepSynced(true);
    _materials.keepSynced(true);
    _workshopDebts.keepSynced(true);
    _workers.keepSynced(true);
    _workerPayments.keepSynced(true);
  }
  static final FirebaseService instance = FirebaseService._();

  static const _writeTimeout = Duration(seconds: 4);

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  DatabaseReference get _customers => _db.ref('customers');
  DatabaseReference get _orders => _db.ref('orders');
  DatabaseReference get _transactions => _db.ref('transactions');
  DatabaseReference get _expenses => _db.ref('expenses');
  DatabaseReference get _users => _db.ref('app_users');
  DatabaseReference get _materials => _db.ref('materials');
  /// نفس أسماء العُقد (nodes) المستخدمة في تطبيق الديسكتوب بالظبط -
  /// عشان الاتنين يشتغلوا على نفس البيانات ويبقوا متزامنين فعليًا
  DatabaseReference get _workshopDebts => _db.ref('workshopDebts');
  DatabaseReference get _workers => _db.ref('workers');
  DatabaseReference get _workerPayments => _db.ref('workerPayments');

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<void> _write(Future<void> Function() operation) async {
    try {
      await operation().timeout(_writeTimeout);
    } on TimeoutException {
      // غالبًا أوفلاين - البيانات محفوظة محليًا وهتتزامن تلقائيًا لاحقًا
    }
  }

  // ---------------- Customers ----------------

  Stream<List<CustomerModel>> streamCustomers() {
    return _customers.onValue.map((event) => _mapSnapshotToList(
          event.snapshot,
          CustomerModel.fromMap,
        )..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  /// بيرجع أول رقم تسلسلي متاح للعميل الجديد = أكبر رقم مستخدم + 1
  /// (نفس منطق الديسكتوب) - قراءة واحدة مباشرة من Firebase
  Future<int> getNextCustomerSerialNumber() async {
    try {
      final snapshot = await _customers.get().timeout(_writeTimeout);
      if (!snapshot.exists || snapshot.value is! Map) return 1;
      var maxSerial = 0;
      final raw = snapshot.value as Map;
      for (final value in raw.values) {
        if (value is Map) {
          final serial = (value['serialNumber'] as num?)?.toInt() ?? 0;
          if (serial > maxSerial) maxSerial = serial;
        }
      }
      return maxSerial + 1;
    } catch (_) {
      return 1;
    }
  }

  Future<String> addCustomer(CustomerModel customer) async {
    final ref = _customers.push();
    await _write(() => ref.set({...customer.toMap(), 'updatedAt': _now}));
    return ref.key!;
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await _write(() => _customers.child(customer.id).update({...customer.toMap(), 'updatedAt': _now}));
  }

  Future<void> deleteCustomer(String id) async {
    await _write(() => _customers.child(id).remove());
  }

  // ---------------- Orders ----------------

  Stream<List<OrderModel>> streamOrders() {
    return _orders.onValue.map((event) => _mapSnapshotToList(
          event.snapshot,
          OrderModel.fromMap,
        )..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Stream<List<OrderModel>> streamOrdersForCustomer(String customerId) {
    return streamOrders().map(
      (orders) => orders.where((o) => o.customerId == customerId).toList(),
    );
  }

  Future<String> addOrder(OrderModel order) async {
    final ref = _orders.push();
    await _write(() => ref.set({...order.toMap(), 'updatedAt': _now}));
    return ref.key!;
  }

  Future<void> updateOrder(OrderModel order) async {
    await _write(() => _orders.child(order.id).update({...order.toMap(), 'updatedAt': _now}));
  }

  Future<void> deleteOrder(String id) async {
    final txSnapshot = await _transactions.orderByChild('orderId').equalTo(id).get();
    final updates = <String, dynamic>{};
    if (txSnapshot.exists) {
      for (final child in txSnapshot.children) {
        updates['transactions/${child.key}'] = null;
      }
    }
    updates['orders/$id'] = null;
    await _write(() => _db.ref().update(updates));
    // ملحوظة: مش بنحذف صور الطلب من Cloudinary هنا - الرفع بيتم بـ
    // Upload Preset غير موقّع (Unsigned) ومفيهوش مفتاح سري في الكود، فمفيش
    // طريقة تحذف بيها ملف من التطبيق مباشرة. نفس سلوك تطبيق الديسكتوب بالظبط.
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _write(() => _orders.child(orderId).update({'status': status, 'updatedAt': _now}));
  }

  Future<String> uploadOrderImageBytes(String orderId, List<int> bytes) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await CloudinaryService.instance.uploadImageBytes(bytes, folder: 'orders/$orderId');
      } catch (e) {
        lastError = e;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    throw lastError ?? Exception('upload_failed');
  }

  /// مفيش حذف فعلي من Cloudinary هنا - الرفع بيتم بـ Upload Preset غير
  /// موقّع (Unsigned) من غير مفتاح سري في الكود، فمفيش طريقة تحذف بيها
  /// ملف من التطبيق مباشرة. الدالة دي بتشيل رابط الصورة بس من قائمة صور
  /// الطلب (imagesJson) - نفس سلوك تطبيق الديسكتوب بالظبط.
  Future<void> deleteOrderImageByUrl(String url) async {}

  // ---------------- Transactions (الدفعات والعربون) ----------------

  Future<void> addPayment({
    required String orderId,
    required String customerId,
    required double amount,
    required String paymentType,
    String paymentMethod = 'cash',
    String status = 'completed',
  }) async {
    final orderRef = _orders.child(orderId);

    await _write(() => orderRef.child('totalPaid').runTransaction((Object? currentData) {
          final current = (currentData as num?)?.toDouble() ?? 0;
          return Transaction.success(current + amount);
        }));
    await _write(() => orderRef.update({'updatedAt': _now}));

    final txRef = _transactions.push();
    await _write(() => txRef.set({
          'orderId': orderId,
          'customerId': customerId,
          'amountPaid': amount,
          'paymentDate': _now,
          'paymentType': paymentType,
          'paymentMethod': paymentMethod,
          'status': status,
        }));
  }

  /// تحديث حالة دفعة معيّنة (معلقة/مكتملة) بس
  Future<void> updatePaymentStatus(String transactionId, String status) async {
    await _write(() => _transactions.child(transactionId).update({'status': status}));
  }

  Stream<List<TransactionModel>> streamTransactionsForOrder(String orderId) {
    return _transactions.orderByChild('orderId').equalTo(orderId).onValue.map(
          (event) => _mapSnapshotToList(event.snapshot, TransactionModel.fromMap)
            ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate)),
        );
  }

  Stream<List<TransactionModel>> streamTransactions() {
    return _transactions.onValue.map((event) => _mapSnapshotToList(
          event.snapshot,
          TransactionModel.fromMap,
        )..sort((a, b) => b.paymentDate.compareTo(a.paymentDate)));
  }

  // ---------------- Expenses ----------------

  Stream<List<ExpenseModel>> streamExpenses() {
    return _expenses.onValue.map((event) => _mapSnapshotToList(
          event.snapshot,
          ExpenseModel.fromMap,
        )..sort((a, b) => b.date.compareTo(a.date)));
  }

  Future<String> addExpense(ExpenseModel expense) async {
    final ref = _expenses.push();
    await _write(() => ref.set({...expense.toMap(), 'updatedAt': _now}));
    return ref.key!;
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await _write(() => _expenses.child(expense.id).update({...expense.toMap(), 'updatedAt': _now}));
  }

  Future<void> restoreExpense(ExpenseModel expense) async {
    await _write(() => _expenses.child(expense.id).set({...expense.toMap(), 'updatedAt': _now}));
  }

  Future<void> deleteExpense(String id) async {
    await _write(() => _expenses.child(id).remove());
  }

  // ---------------- Workshop Debts (ديون الورشة للموردين/الصنايعية) ----------------

  Stream<List<WorkshopDebtModel>> streamWorkshopDebts() {
    return _workshopDebts.onValue.map((event) => _mapSnapshotToList(
          event.snapshot,
          WorkshopDebtModel.fromMap,
        )..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Future<String> addWorkshopDebt(WorkshopDebtModel debt) async {
    final ref = _workshopDebts.push();
    await _write(() => ref.set({...debt.toMap(), 'updatedAt': _now}));
    return ref.key!;
  }

  Future<void> updateWorkshopDebt(WorkshopDebtModel debt) async {
    await _write(() => _workshopDebts.child(debt.id).update({...debt.toMap(), 'updatedAt': _now}));
  }

  Future<void> deleteWorkshopDebt(String id) async {
    await _write(() => _workshopDebts.child(id).remove());
  }

  /// سداد جزء من مديونية ورشة: بيزوّد paidAmount على المديونية، وبيسجّل
  /// مصروف مرتبط بنوع "سداد مديونية ورشة" - نفس سلوك الديسكتوب بالظبط
  Future<void> payWorkshopDebt({
    required WorkshopDebtModel debt,
    required double amount,
    required String paymentMethod,
  }) async {
    final newPaid = debt.paidAmount + amount;
    await updateWorkshopDebt(debt.copyWith(paidAmount: newPaid));

    final expense = ExpenseModel(
      id: '',
      amount: amount,
      category: 'workshop_debt',
      description: 'سداد لـ ${debt.creditorName}',
      paymentMethod: paymentMethod,
      workshopDebtId: debt.id,
      date: DateTime.now(),
    );
    await addExpense(expense);
  }

  // ---------------- Workers (العمال) ----------------

  Stream<List<WorkerModel>> streamWorkers() {
    return _workers.onValue.map((event) => _mapSnapshotToList(
          event.snapshot,
          WorkerModel.fromMap,
        )..sort((a, b) => a.name.compareTo(b.name)));
  }

  Future<String> addWorker(WorkerModel worker) async {
    final ref = _workers.push();
    await _write(() => ref.set({...worker.toMap(), 'updatedAt': _now}));
    return ref.key!;
  }

  Future<void> updateWorker(WorkerModel worker) async {
    await _write(() => _workers.child(worker.id).update({...worker.toMap(), 'updatedAt': _now}));
  }

  Future<void> deleteWorker(String id) async {
    await _write(() => _workers.child(id).remove());
  }

  Stream<List<WorkerPaymentModel>> streamWorkerPayments() {
    return _workerPayments.onValue.map((event) => _mapSnapshotToList(
          event.snapshot,
          WorkerPaymentModel.fromMap,
        )..sort((a, b) => b.paymentDate.compareTo(a.paymentDate)));
  }

  /// تسجيل تأكيد قبض عامل لمرتبه: بيضيف سطر في سجل القبض، وبيسجّل مصروف
  /// "أجور" مرتبط بيه أوتوماتيك - عشان يدخل في حساب الأرباح والتقارير
  Future<void> confirmWorkerPayment({
    required WorkerModel worker,
    required DateTime periodStart,
    String paymentMethod = 'cash',
  }) async {
    final expense = ExpenseModel(
      id: '',
      amount: worker.salaryAmount,
      category: 'wages',
      description: 'مرتب ${worker.name}',
      workerName: worker.name,
      paymentMethod: paymentMethod,
      date: DateTime.now(),
    );
    final expenseId = await addExpense(expense);

    final ref = _workerPayments.push();
    await _write(() => ref.set({
          'workerId': worker.id,
          'workerName': worker.name,
          'amount': worker.salaryAmount,
          'paymentDate': _now,
          'periodStart': periodStart.millisecondsSinceEpoch,
          'expenseId': expenseId,
        }));
  }

  // ---------------- App Users (حسابات دخول إضافية للعمال) ----------------

  Stream<List<UserAccountModel>> streamUsers() {
    return _users.onValue.map((event) => _mapSnapshotToList(
          event.snapshot,
          UserAccountModel.fromMap,
        )..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
  }

  Future<String> addUser(String username, String password) async {
    final ref = _users.push();
    await _write(() => ref.set({
          'username': username,
          'password': password,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        }));
    return ref.key!;
  }

  Future<void> updateUserPassword(String userId, String newPassword) async {
    await _write(() => _users.child(userId).update({'password': newPassword}));
  }

  Future<void> deleteUser(String userId) async {
    await _write(() => _users.child(userId).remove());
  }

  Future<bool> verifyExtraUser(String username, String password) async {
    DataSnapshot snapshot;
    try {
      snapshot = await _users.get().timeout(_writeTimeout);
    } catch (_) {
      return false;
    }
    if (!snapshot.exists || snapshot.value == null) return false;
    final raw = snapshot.value;
    if (raw is! Map) return false;
    for (final value in raw.values) {
      if (value is Map) {
        final u = value['username']?.toString() ?? '';
        final p = value['password']?.toString() ?? '';
        if (u == username && p == password) return true;
      }
    }
    return false;
  }

  // ---------------- Materials (مخزون الخامات) ----------------

  Stream<List<MaterialItemModel>> streamMaterials() {
    return _materials.onValue.map((event) => _mapSnapshotToList(
          event.snapshot,
          MaterialItemModel.fromMap,
        )..sort((a, b) => a.name.compareTo(b.name)));
  }

  Future<String> addMaterial(MaterialItemModel material) async {
    final ref = _materials.push();
    await _write(() => ref.set({...material.toMap(), 'updatedAt': _now}));
    return ref.key!;
  }

  Future<void> updateMaterial(MaterialItemModel material) async {
    await _write(() => _materials.child(material.id).update({...material.toMap(), 'updatedAt': _now}));
  }

  /// تعديل سريع للكمية (+ إضافة أو - خصم) باستخدام Transaction عشان لو
  /// أكتر من جهاز بيعدّل في نفس اللحظة الرقم يفضل صح ومفيش تضارب
  Future<void> adjustMaterialQuantity(String id, double delta) async {
    await _write(() => _materials.child(id).child('quantity').runTransaction((Object? currentData) {
          final current = (currentData as num?)?.toDouble() ?? 0;
          final newValue = current + delta;
          return Transaction.success(newValue < 0 ? 0 : newValue);
        }));
    await _write(() => _materials.child(id).update({'updatedAt': _now}));
  }

  Future<void> deleteMaterial(String id) async {
    await _write(() => _materials.child(id).remove());
  }

  // ---------------- Helper ----------------

  List<T> _mapSnapshotToList<T>(
    DataSnapshot snapshot,
    T Function(String id, Map<dynamic, dynamic> map) fromMap,
  ) {
    if (!snapshot.exists || snapshot.value == null) return [];
    final raw = snapshot.value;
    if (raw is! Map) return [];
    final result = <T>[];
    raw.forEach((key, value) {
      if (value is Map) {
        try {
          result.add(fromMap(key.toString(), value));
        } catch (_) {}
      }
    });
    return result;
  }
}
