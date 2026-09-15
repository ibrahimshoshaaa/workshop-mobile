import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../services/customer_archive_service.dart';

final customerArchiveServiceProvider = Provider<CustomerArchiveService>((ref) => CustomerArchiveService.instance);

final allCustomersArchiveProvider = StreamProvider<List<CustomerModel>>((ref) {
  return ref.watch(customerArchiveServiceProvider).streamAllCustomers();
});

final archivedCustomersProvider = StreamProvider<List<CustomerModel>>((ref) {
  return ref.watch(customerArchiveServiceProvider).streamArchivedCustomers();
});

final archivedOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(customerArchiveServiceProvider).streamArchivedOrders();
});

final customerArchiveSearchProvider = StateProvider<String>((ref) => '');

/// تطبيع بسيط للبحث العربي، عشان البحث بـ "ابو" يلاقي "أبو"،
/// وكمان اختلافات الهمزات والألف/الياء ما تمنعش ظهور العميل.
String normalizeCustomerSearch(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ٱ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '');
}

final combinedCustomerSearchProvider = Provider<List<CustomerModel>>((ref) {
  final customers = ref.watch(allCustomersArchiveProvider).value ?? const <CustomerModel>[];
  final query = normalizeCustomerSearch(ref.watch(customerArchiveSearchProvider));

  // من غير بحث: العملاء النشطين فقط.
  // مع البحث: نبحث في العملاء النشطين + المؤرشفين.
  if (query.isEmpty) return customers.where((c) => !c.isArchived).toList();

  return customers.where((c) {
    final name = normalizeCustomerSearch(c.name);
    final phone = normalizeCustomerSearch(c.phone);
    final serial = c.serialNumber.toString();
    return name.contains(query) || phone.contains(query) || serial.contains(query);
  }).toList();
});
