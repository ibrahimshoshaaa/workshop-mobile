import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/expense_model.dart';
import '../models/user_account_model.dart';

class FirebaseService {
  FirebaseService._() {
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

  Future<String> uploadOrderImageBytes(String orderId, List<int> bytes) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref('orders/$orderId/$fileName');
    await ref.putData(Uint8List.fromList(bytes));
    return ref.getDownloadURL();
  }

  Future<void> deleteOrderImageByUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {}
  }

  // ---------------- Transactions (الدفعات والعربون) ----------------

  Future<void> addPayment({
    required String orderId,
    required String customerId,
    required double amount,
    required String paymentType,
  }) async {
    final orderRef = _orders.child(orderId);

    await _write(() => orderRef.child('totalPaid').runTransaction((Object? currentData) {
          final current = (currentData
