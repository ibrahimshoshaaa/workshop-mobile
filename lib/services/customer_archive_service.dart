import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';

class CustomerArchiveService {
  CustomerArchiveService._();
  static final instance = CustomerArchiveService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  DatabaseReference get _customers => _db.ref('customers');
  DatabaseReference get _orders => _db.ref('orders');

  static const _timeout = Duration(seconds: 5);

  Stream<List<CustomerModel>> streamAllCustomers() {
    return _customers.onValue.map((event) {
      final result = <CustomerModel>[];
      for (final child in event.snapshot.children) {
        final value = child.value;
        if (value is Map) result.add(CustomerModel.fromMap(child.key!, value));
      }
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    });
  }

  Stream<List<CustomerModel>> streamArchivedCustomers({int? year}) {
    return streamAllCustomers().map((customers) => customers.where((c) {
      if (!c.isArchived) return false;
      return year == null || c.archiveYear == year;
    }).toList());
  }

  Stream<List<OrderModel>> streamAllOrders() {
    return _orders.onValue.map((event) {
      final result = <OrderModel>[];
      for (final child in event.snapshot.children) {
        final value = child.value;
        if (value is Map) result.add(OrderModel.fromMap(child.key!, value));
      }
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    });
  }

  Stream<List<OrderModel>> streamArchivedOrders({String? customerId, int? year}) {
    return streamAllOrders().map((orders) => orders.where((o) {
      if (!o.isArchived) return false;
      if (customerId != null && o.customerId != customerId) return false;
      return year == null || o.archiveYear == year;
    }).toList());
  }

  Future<String?> getArchiveBlockReason(String customerId) async {
    try {
      final snapshot = await _orders.get().timeout(_timeout);
      for (final child in snapshot.children) {
        final value = child.value;
        if (value is! Map) continue;
        final order = OrderModel.fromMap(child.key!, value);
        if (order.customerId != customerId || order.isArchived) continue;
        if (order.remainingAmount > 0.01) {
          return 'لا يمكن أرشفة العميل لأن عليه مبلغًا متبقيًا.';
        }
        if (order.status != 'تم التسليم') {
          return 'لا يمكن أرشفة العميل لأن لديه طلبًا لم يتم تسليمه بعد.';
        }
      }
      return null;
    } catch (_) {
      return 'تعذر التحقق من حالة الطلبات. حاول مرة أخرى.';
    }
  }

  Future<void> archiveCustomer(String customerId) async {
    final reason = await getArchiveBlockReason(customerId);
    if (reason != null) throw StateError(reason);

    final now = DateTime.now();
    final updates = <String, dynamic>{
      'customers/$customerId/isArchived': true,
      'customers/$customerId/archivedAt': now.millisecondsSinceEpoch,
      'customers/$customerId/archiveYear': now.year,
      'customers/$customerId/updatedAt': now.millisecondsSinceEpoch,
    };

    final snapshot = await _orders.get().timeout(_timeout);
    for (final child in snapshot.children) {
      final value = child.value;
      if (value is! Map) continue;
      final order = OrderModel.fromMap(child.key!, value);
      if (order.customerId == customerId && !order.isArchived) {
        updates['orders/${child.key}/isArchived'] = true;
        updates['orders/${child.key}/archivedAt'] = now.millisecondsSinceEpoch;
        updates['orders/${child.key}/archiveYear'] = now.year;
        updates['orders/${child.key}/updatedAt'] = now.millisecondsSinceEpoch;
      }
    }
    await _db.ref().update(updates).timeout(_timeout);
  }

  /// يعيد العميل والطلبات التابعة له من الأرشيف معًا.
  ///
  /// مهم: الطلبات نفسها هي التي تحمل isArchived، وهي التي يتم استبعادها
  /// من الطلبات والإجماليات الحالية. لذلك إعادة العميل وحده لا تكفي؛ لازم
  /// نفك أرشفة كل طلبات العميل في نفس الـ multi-location update.
  Future<int> reactivateCustomer(String customerId) async {
    final snapshot = await _orders.get().timeout(_timeout);
    final updates = <String, dynamic>{
      'customers/$customerId/isArchived': false,
      'customers/$customerId/archivedAt': null,
      'customers/$customerId/archiveYear': null,
      'customers/$customerId/updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    var restoredOrders = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final child in snapshot.children) {
      final value = child.value;
      if (value is! Map) continue;
      final order = OrderModel.fromMap(child.key!, value);
      if (order.customerId == customerId && order.isArchived) {
        updates['orders/${child.key}/isArchived'] = false;
        updates['orders/${child.key}/archivedAt'] = null;
        updates['orders/${child.key}/archiveYear'] = null;
        updates['orders/${child.key}/updatedAt'] = now;
        restoredOrders++;
      }
    }

    await _db.ref().update(updates).timeout(_timeout);
    return restoredOrders;
  }

  Future<CustomerModel?> findByPhoneOrName(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    final snapshot = await _customers.get().timeout(_timeout);
    for (final child in snapshot.children) {
      final value = child.value;
      if (value is! Map) continue;
      final customer = CustomerModel.fromMap(child.key!, value);
      if (customer.phone.trim() == q || customer.name.trim().toLowerCase() == q) {
        return customer;
      }
    }
    return null;
  }
}
