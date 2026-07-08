import 'dart:typed_data';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/expense_model.dart';

/// طبقة الوصول لـ Realtime Database. كل التعامل مع قاعدة البيانات يمر من هنا.
/// اخترنا Realtime Database بدل Firestore عشان قواعد الأمان بتتظبط مباشرة
/// من صفحة الـ Console (Publish بضغطة زرار) من غير أي حاجة تتنشر بالـ CLI.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  DatabaseReference get _customers => _db.ref('customers');
  DatabaseReference get _orders => _db.ref('orders');
  DatabaseReference get _transactions => _db.ref('transactions');
  DatabaseReference get _expenses => _db.ref('expenses');

  // ---------------- Customers ----------------

  Stream<List<CustomerModel>> streamCustomers() {
    return _customers.onValue.map((event) => _mapSnapshotToList(
          event.snapshot,
          CustomerModel.fromMap,
        )..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Future<String> addCustomer(CustomerModel customer) async {
    final ref = _customers.push();
    await ref.set(customer.toMap());
    return ref.key!;
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await _customers.child(customer.id).update(customer.toMap());
  }

  Future<void> deleteCustomer(String id) async {
    await _customers.child(id).remove();
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
    await ref.set(order.toMap());
    return ref.key!;
  }

  Future<void> updateOrder(OrderModel order) async {
    await _orders.child(order.id).update(order.toMap());
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
    await _db.ref().update(updates);

    // حذف صور الطلب من Storage (لو موجودة) - أي خطأ هنا بيتجاهل عشان
    // مايوقفش حذف الطلب نفسه
    try {
      final imagesRef = _storage.ref('orders/$id');
      final listResult = await imagesRef.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
    } catch (_) {}
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _orders.child(orderId).update({'status': status});
  }

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

    // ✅ صح: استخدم MutableData وحدد القيمة ثم ارجع Transaction.success
    await orderRef.child('totalPaid').runTransaction((MutableData currentData) {
      final current = (currentData.value as num?)?.toDouble() ?? 0;
      currentData.value = current + amount;
      return Transaction.success(currentData);
    });

    final txRef = _transactions.push();
    await txRef.set({
      'orderId': orderId,
      'customerId': customerId,
      'amountPaid': amount,
      'paymentDate': DateTime.now().millisecondsSinceEpoch,
      'paymentType': paymentType,
    });
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
    await ref.set(expense.toMap());
    return ref.key!;
  }

  Future<void> deleteExpense(String id) async {
    await _expenses.child(id).remove();
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
