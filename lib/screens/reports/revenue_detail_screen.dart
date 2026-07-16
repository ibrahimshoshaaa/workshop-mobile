import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/order_model.dart';
import '../../providers/app_providers.dart';
import '../../widgets/privacy_blur.dart';

/// شاشة تفاصيل الإيرادات - جدول مفصّل للطلبات في فترة معيّنة، قابل
/// للفرز والفلترة بالحالة والبحث، مع إجمالي الاتفاق/المدفوع/الخصم/المتبقي
class RevenueDetailScreen extends ConsumerStatefulWidget {
  const RevenueDetailScreen({super.key});

  @override
  ConsumerState<RevenueDetailScreen> createState() => _RevenueDetailScreenState();
}

class _RevenueDetailScreenState extends ConsumerState<RevenueDetailScreen> {
  late DateTimeRange _range;
  String? _statusFilter;
  bool _sortAscending = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersStreamProvider).value ?? [];
    final dateFormatter = DateFormat('d/M/yyyy', 'ar');

    var filtered = orders.where((o) {
      return o.createdAt.isAfter(_range.start) && o.createdAt.isBefore(_range.end.add(const Duration(days: 1)));
    }).toList();

    if (_statusFilter != null) {
      filtered = filtered.where((o) => o.status == _statusFilter).toList();
    }
    if (_query.isNotEmpty) {
      filtered = filtered
          .where((o) => o.customerName.contains(_query) || o.itemType.contains(_query))
          .toList();
    }
    filtered.sort((a, b) => _sortAscending ? a.createdAt.compareTo(b.createdAt) : b.createdAt.compareTo(a.createdAt));

    final totalAgreed = filtered.fold<double>(0, (s, o) => s + o.totalAmount);
    final totalPaid = filtered.fold<double>(0, (s, o) => s + o.totalPaid);
    final totalDiscount = filtered.fold<double>(0, (s, o) => s + o.discountAmount);
    final totalRemaining = filtered.fold<double>(0, (s, o) => s + o.remainingAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الإيرادات'),
        actions: [
          IconButton(
            icon: Icon(_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
            tooltip: 'ترتيب حسب التاريخ',
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_rounded),
                    label: Text('${dateFormatter.format(_range.start)} - ${dateFormatter.format(_range.end)}'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'ابحث بالعميل أو الصنف...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: const Text('الكل'),
                    selected: _statusFilter == null,
                    onSelected: (_) => setState(() => _statusFilter = null),
                  ),
                  const SizedBox(width: 8),
                  ...AppConstants.orderStatuses.map((s) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(s),
                          selected: _statusFilter == s,
                          onSelected: (_) => setState(() => _statusFilter = _statusFilter == s ? null : s),
                        ),
                      )),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.wood.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: PrivacyBlur(
              child: Column(
                children: [
                  _summaryRow('إجمالي الاتفاقات', totalAgreed),
                  _summaryRow('إجمالي المحصّل', totalPaid, color: AppColors.success),
                  if (totalDiscount > 0) _summaryRow('إجمالي الخصومات', totalDiscount, color: AppColors.warning),
                  _summaryRow('إجمالي المتبقي', totalRemaining, color: AppColors.danger),
                ],
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('لا توجد طلبات في الفترة المحددة', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _OrderRevenueTile(
                      order: filtered[index],
                      dateFormatter: dateFormatter,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text('${amount.toStringAsFixed(0)} ج.م',
              style: TextStyle(fontWeight: FontWeight.bold, color: color ?? AppColors.wood)),
        ],
      ),
    );
  }
}

class _OrderRevenueTile extends StatelessWidget {
  final OrderModel order;
  final DateFormat dateFormatter;
  const _OrderRevenueTile({required this.order, required this.dateFormatter});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => context.push('/orders/${order.id}'),
        title: Text('${order.customerName} - ${order.itemType}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${dateFormatter.format(order.createdAt)} - ${order.status}'),
        trailing: PrivacyBlur(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${order.totalAmount.toStringAsFixed(0)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                order.remainingAmount > 0 ? 'متبقي ${order.remainingAmount.toStringAsFixed(0)}' : 'مدفوع بالكامل',
                style: TextStyle(
                  fontSize: 12,
                  color: order.remainingAmount > 0 ? AppColors.danger : AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
