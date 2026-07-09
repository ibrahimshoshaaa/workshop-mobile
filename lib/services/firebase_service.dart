import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/expense_model.dart';
import '../models/user_account_model.dart';

/// طبقة الوصول لـ Realtime Database. كل التعامل مع قاعدة البيانات يمر من هنا.
///
/// أوفلاين-أولًا: كل الكتابات (إضافة/تعديل/حذف) بتتحفظ على الجهاز فورًا
/// (بفضل setPersistenceEnabled في main.dart) وتتزامن تلقائيًا مع السيرفر
/// لحظة رجوع النت. عشان الشاشة متفضلش عالقة "بتحفظ..." وقت انقطاع النت،
/// بنحط مهلة قصيرة (_writeTimeout) بعد ما الكتابة المحلية تتم - لو السيرفر
/// ماردّش خلالها (يعني غالبًا أوفلاين)، بنكمل عادي لأن البيانات أصلاً
/// محفوظة محليًا ومضمون تتزامن لاحقًا.
class FirebaseService {
  FirebaseService._() {
    // نخلي الأقسام الأساسية "متزامنة دايمًا" محليًا حتى لو محدش فاتح
    // الشاشة بتاعتها، عشان تبقى متاحة أوفلاين من أول لحظة فتح التطبيق
    _customers.keepSynced(true);
    _orders.keepSynced(true);
    _transactions.keepSynced(true);
    _expenses.keepSynced(true);
    _users.keepSynced(true);
  }
  static final FirebaseService instance = FirebaseService._();

  static const _writeTimeout = Duration(seconds: 4);

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  DatabaseReference get _customers => _db.ref('customers');
  DatabaseReference get _orders => _db.ref('orders');
  DatabaseReference get _transactions => _db.ref('transactions');
  DatabaseReference get _expenses => _db.ref('expenses');
  DatabaseReference get _users => _db.ref('app_users');

  /// نفّذ أي عملية كتابة (set/update/remove) من غير ما نعلّق التطبيق لو
  /// النت مقطوع - البيانات بتتحفظ محليًا فورًا بفضل Offline Persistence،
  /// وبنستنى تأكيد السيرفر لمهلة قصيرة بس مش أكتر
  Future<void> _write(Future<void> Function() operation) async {
    try {
      await operation().timeout(_writeTimeout);
    } on TimeoutException {
      // غالبًا أوفلاين - البيانات محفوظة محليًا بالفعل وهتتزامن تلقائيًا
      // لحظة رجوع النت، فمش هنعتبرها خطأ
    }
  }

  // ---------------- Customers ----------------

  Stream<List<CustomerModel>> streamCustomers() {
    return _customers.onValue.map((event) => _mapSnapshotToList(
          event.snapshot,
          CustomerModel.fromMap,
        )..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Future<String> addCustomer(CustomerModel customer) async {
    final ref = _customers.push();
    await _write(() => ref.set(customer.toMap()));
    return ref.key!;
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await _write(() => _customers.child(customer.id).update(customer.toMap()));
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
    await _write(() => ref.set(order.toMap()));
    return ref.key!;
  }

  Future<void> updateOrder(OrderModel order) async {
    await _write(() => _orders.child(order.id).update(order.toMap()));
  }

  /// حذف الطلب + كل الدفعات المرتبطة بيه (RTDB مالوش قواعد صارمة تمنع
  /// الحذف زي Firestore، فالتنضيف بسيط ومباشر من غير Cloud Function)
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

    // حذف صور الطلب من Storage (لو موجودة) - أي خطأ هنا بيتجاهل عشان
    // مايوقفش حذف الطلب نفسه (وبرضه بيحتاج نت أصلاً، فمش جزء من منطق الأوفلاين)
    try {
      final imagesRef = _storage.ref('orders/$id');
      final listResult = await imagesRef.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
    } catch (_) {}
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _write(() => _orders.child(orderId).update({'status': status}));
  }

  /// رفع صور الطلب محتاج نت فعليًا (مش جزء من منطق الأوفلاين - الصور
  /// مش بتتخزن في Realtime Database، فهنسيبها تنتظر السيرفر عادي)
  Future<String> uploadOrderImageBytes(String orderId, List<int> bytes) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref('orders/$orderId/$fileName');
    await ref.putData(Uint8List.fromList(bytes));
    return ref.getDownloadURL();
  }

  // ---------------- Transactions (الدفعات والعربون) ----------------

  /// إضافة دفعة جديدة (عربون أو قسط) وتحديث totalPaid في الطلب تلقائيًا
  /// عن طريق runTransaction، عشان لو أكتر من جهاز بيدفع في نفس اللحظة
  /// الأرقام تفضل صح ومفيش تضارب
  Future<void> addPayment({
    required String orderId,
    required String customerId,
    required double amount,
    required String paymentType,
  }) async {
    final orderRef = _orders.child(orderId);

    // firebase_database 11.x: القيمة بتيجي مباشرة (Object?) من غير غلاف
    // MutableData زي الإصدارات القديمة، والـ Transaction.success بياخد
    // القيمة الجديدة مباشرة برضه
    await _write(() => orderRef.child('totalPaid').runTransaction((Object? currentData) {
          final current = (currentData as num?)?.toDouble() ?? 0;
          return Transaction.success(current + amount);
        }));

    final txRef = _transactions.push();
    await _write(() => txRef.set({
          'orderId': orderId,
          'customerId': customerId,
          'amountPaid': amount,
          'paymentDate': DateTime.now().millisecondsSinceEpoch,
          'paymentType': paymentType,
        }));
  }

  Stream<List<TransactionModel>> streamTransactionsForOrder(String orderId) {
    return _transactions.orderByChild('orderId').equalTo(orderId).onValue.map(
          (event) => _mapSnapshotToList(event.snapshot, TransactionModel.fromMap)
            ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate)),
        );
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
    await _write(() => ref.set(expense.toMap()));
    return ref.key!;
  }

  Future<void> deleteExpense(String id) async {
    await _write(() => _expenses.child(id).remove());
  }
  Future<void> updateExpense(ExpenseModel expense) async {
    await _write(() => _expenses.child(expense.id).update(expense.toMap()));
  }

  /// تُستخدم لاستعادة مصروف اتحذف بالغلط (زرار "تراجع" في السنابار)
  Future<void> restoreExpense(ExpenseModel expense) async {
    await _write(() => _expenses.child(expense.id).set(expense.toMap()));
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

  /// يتحقق من اسم المستخدم/الباسورد مقابل الحسابات الإضافية المخزّنة في
  /// app_users وقت تسجيل الدخول. لازم يبقى فيه نت أول مرة (أو تكون
  /// keepSynced خزّنت نسخة محلية قبل كده) عشان يشتغل أوفلاين
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

  // ---------------- Helper ----------------

  /// يحوّل أي DataSnapshot من RTDB (Map بمفاتيح = الـ id بتاع كل عنصر)
  /// لقائمة عناصر مقروءة، بيتجاهل أي عنصر تالف بدل ما يوقف التطبيق كله
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
        } catch (_) {
          // تجاهل أي سجل تالف
        }
      }
    });
    return result;
  }
}
