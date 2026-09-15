import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_state.dart';
import '../../core/theme/app_theme.dart';
import '../../models/order_model.dart';
import '../../providers/customer_archive_providers.dart';
import '../../services/customer_archive_service.dart';

class CustomerArchiveScreen extends ConsumerStatefulWidget {
  const CustomerArchiveScreen({super.key});

  @override
  ConsumerState<CustomerArchiveScreen> createState() => _CustomerArchiveScreenState();
}

class _CustomerArchiveScreenState extends ConsumerState<CustomerArchiveScreen> {
  final _searchController = TextEditingController();
  int? _year;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showOrder(OrderModel order) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.itemType, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('العميل: ${order.customerName}'),
              Text('الحالة: ${order.status}'),
              Text('الإجمالي بعد الخصم: ${(order.totalAmount - order.discountAmount).toStringAsFixed(0)} جنيه'),
              Text('المدفوع: ${order.totalPaid.toStringAsFixed(0)} جنيه'),
              if (order.discountAmount > 0) Text('الخصم: ${order.discountAmount.toStringAsFixed(0)} جنيه'),
              if (order.details.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('التفاصيل', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(order.details),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reactivate(String customerId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعادة تنشيط العميل'),
        content: Text('إعادة $name إلى العملاء النشطين؟\nالطلبات القديمة ستظل مؤرشفة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إعادة تنشيط')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CustomerArchiveService.instance.reactivateCustomer(customerId);
      ref.invalidate(archivedCustomersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إعادة تنشيط العميل بنجاح')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إعادة تنشيط العميل')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthState.isAdmin) {
      return const Scaffold(body: Center(child: Text('هذه الصفحة متاحة للأدمن فقط')));
    }

    final archivedAsync = ref.watch(archivedCustomersProvider);
    final ordersAsync = ref.watch(archivedOrdersProvider);
    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('أرشيف العملاء'),
        actions: [
          if (_year != null)
            IconButton(
              tooltip: 'إلغاء فلتر السنة',
              onPressed: () => setState(() => _year = null),
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
        ],
      ),
      body: archivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('تعذر تحميل الأرشيف: $e')),
        data: (customers) {
          final years = customers.map((c) => c.archiveYear).whereType<int>().toSet().toList()..sort((a, b) => b.compareTo(a));
          var filtered = customers.where((c) {
            final matchesYear = _year == null || c.archiveYear == _year;
            final matchesSearch = query.isEmpty ||
                c.name.toLowerCase().contains(query) ||
                c.phone.toLowerCase().contains(query) ||
                c.serialNumber.toString().contains(query);
            return matchesYear && matchesSearch;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو الهاتف أو الرقم التسلسلي...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() {}); }, icon: const Icon(Icons.clear_rounded)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              if (years.isNotEmpty)
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      ChoiceChip(label: const Text('كل السنين'), selected: _year == null, onSelected: (_) => setState(() => _year = null)),
                      const SizedBox(width: 8),
                      ...years.map((y) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(label: Text('$y'), selected: _year == y, onSelected: (_) => setState(() => _year = y)),
                      )),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Text('${filtered.length} عميل مؤرشف', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Icon(Icons.archive_rounded, size: 18, color: AppColors.wood),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('لا توجد سجلات مؤرشفة'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final customer = filtered[index];
                          final customerOrders = (ordersAsync.value ?? const <OrderModel>[]).where((o) => o.customerId == customer.id).toList();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ExpansionTile(
                              leading: CircleAvatar(child: Text(customer.name.isEmpty ? '?' : customer.name[0])),
                              title: Row(
                                children: [
                                  Flexible(child: Text(customer.name, overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 8),
                                  const Chip(label: Text('مؤرشف', style: TextStyle(fontSize: 11))),
                                ],
                              ),
                              subtitle: Text('${customer.phone} • #${customer.serialNumber} • ${customer.archiveYear ?? ''}'),
                              children: [
                                if (customerOrders.isEmpty)
                                  const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد طلبات مؤرشفة لهذا العميل'))
                                else
                                  ...customerOrders.map((order) => ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.receipt_long_rounded),
                                    title: Text(order.itemType),
                                    subtitle: Text('${order.status} • ${order.deliveryDate.day}/${order.deliveryDate.month}/${order.deliveryDate.year}'),
                                    trailing: Text('${(order.totalAmount - order.discountAmount).toStringAsFixed(0)} ج'),
                                    onTap: () => _showOrder(order),
                                  )),
                                if (AuthState.isAdmin)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _reactivate(customer.id, customer.name),
                                        icon: const Icon(Icons.restore_rounded),
                                        label: const Text('إعادة تنشيط العميل'),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
