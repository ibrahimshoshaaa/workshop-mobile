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

final combinedCustomerSearchProvider = Provider<List<CustomerModel>>((ref) {
  final customers = ref.watch(allCustomersArchiveProvider).value ?? const <CustomerModel>[];
  final query = ref.watch(customerArchiveSearchProvider).trim().toLowerCase();
  if (query.isEmpty) return customers.where((c) => !c.isArchived).toList();
  return customers.where((c) {
    return c.name.toLowerCase().contains(query) ||
        c.phone.toLowerCase().contains(query) ||
        c.serialNumber.toString().contains(query);
  }).toList();
});
