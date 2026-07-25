import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../providers/app_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/privacy_blur.dart';
import '../../widgets/modern_ui.dart';

/// مفتاح خاص (مش فئة مصروف حقيقية) بنستخدمه بس كفلتر داخل الشاشة دي عشان
/// نعرض "مرتجعات العملاء" لوحدها - المرتجعات دي مش ExpenseModel حقيقي،
/// دي دفعات سالبة (refund) مسجلة على الطلب نفسه (شوف payWorkshopDebt في
/// firebase_service.dart) عشان منخصمش "المتاح نقدي" مرتين. هنا بنجمعها بس
/// للعرض عشان تبقى مرئية للمستخدم في مكان واحد
const _refundFilterKey = '__refund__';

/// عنصر عرض موحّد لصف "مرتجع لعميل" - مبني من TransactionModel بنوع refund
class _RefundEntry {
  final String id;
  final double amount;
  final DateTime date;
  final String customerName;
  final String itemType;
  final String orderId;
  const _RefundEntry({
    required this.id,
    required this.amount,
    required this.date,
    required this.customerName,
    required this.itemType,
    required this.orderId,
  });
}

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(filteredExpensesProvider);
    final selectedCategory = ref.watch(expenseCategoryFilterProvider);
    final workerAdvances = ref.watch(workerAdvancesProvider);

    // بناء قايمة "مرتجعات العملاء" - الدفعات السالبة (refund) المسجلة على
    // الطلبات نتيجة سداد مديونية ورشة ناتجة من دفع عميل زيادة عن الاتفاق
    final orders = ref.watch(ordersStreamProvider).value ?? [];
    final transactions = ref.watch(transactionsStreamProvider).value ?? [];
    final refundEntries = transactions
        .where((t) => t.paymentType == AppConstants.paymentRefund)
        .map((t) {
          final order = orders.where((o) => o.id == t.orderId).firstOrNull;
          return _RefundEntry(
            id: t.id,
            amount: t.amountPaid.abs(),
            date: t.paymentDate,
            customerName: order?.customerName ?? 'عميل محذوف',
            itemType: order?.itemType ?? '',
            orderId: t.orderId,
          );
        })
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final showRefunds = selectedCategory == null || selectedCategory == _refundFilterKey;
    final showRealExpenses = selectedCategory != _refundFilterKey;
    final visibleRefunds = showRefunds ? refundEntries : <_RefundEntry>[];
    final visibleExpenses = showRealExpenses ? expenses : <dynamic>[];
    final isEmpty = visibleRefunds.isEmpty && visibleExpenses.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('المصروفات')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.wood,
        onPressed: () => context.push('/expenses/add'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                ModernChip(
                  label: 'الكل',
                  selected: selectedCategory == null,
                  onTap: () => ref.read(expenseCategoryFilterProvider.notifier).state = null,
                ),
                const SizedBox(width: 8),
                ...AppConstants.expenseCategories.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ModernChip(
                        label: e.value,
                        selected: selectedCategory == e.key,
                        onTap: () => ref.read(expenseCategoryFilterProvider.notifier).state = e.key,
                      ),
                    )),
                if (refundEntries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ModernChip(
                      label: 'مرتجعات عملاء',
                      selected: selectedCategory == _refundFilterKey,
                      onTap: () => ref.read(expenseCategoryFilterProvider.notifier).state = _refundFilterKey,
                    ),
                  ),
              ],
            ),
          ),
          if (selectedCategory == 'wages' && workerAdvances.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إجمالي السحبيات لكل صنايعي', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...workerAdvances.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [Text(e.key), Text('${e.value.toStringAsFixed(0)} ج.م')],
                        ),
                      )),
                ],
              ),
            ),
          Expanded(
            child: isEmpty
                ? const ModernEmptyState(icon: Icons.receipt_long_outlined, message: 'لا توجد مصروفات مسجلة')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      ...visibleRefunds.map((r) => ModernListCard(
                            onTap: () => context.push('/orders/${r.orderId}'),
                            leading: const ModernIconBadge(icon: Icons.undo_rounded, color: AppColors.wood),
                            title: Text('مرتجع لـ ${r.customerName}${r.itemType.isNotEmpty ? ' - ${r.itemType}' : ''}'),
                            subtitle: Text(
                              'دفع أكتر من الاتفاق واسترجع الفرق | ${DateFormat('d/M/yyyy').format(r.date)}',
                            ),
                            trailing: PrivacyBlur(
                              child: Text('${r.amount.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.wood, fontSize: 13)),
                            ),
                          )),
                      ...visibleExpenses.map((e) => _buildExpenseRow(context, ref, e)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseRow(BuildContext context, WidgetRef ref, dynamic e) {
    return Dismissible(
                        key: ValueKey(e.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(18)),
                          child: const Icon(Icons.delete_rounded, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('حذف المصروف'),
                                  content: const Text('هل أنت متأكد من حذف هذا المصروف؟'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) async {
                          final removed = e;
                          final messenger = ScaffoldMessenger.of(context);
                          await ref.read(firebaseServiceProvider).deleteExpense(e.id);
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('تم حذف المصروف'),
                              action: SnackBarAction(
                                label: 'تراجع',
                                onPressed: () => ref.read(firebaseServiceProvider).restoreExpense(removed),
                              ),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        },
                        child: ModernListCard(
                          onTap: () => context.push('/expenses/${e.id}/edit'),
                          leading: ModernIconBadge(icon: _iconFor(e.category), color: AppColors.wood),
                          title: Text(e.description.isNotEmpty
                              ? e.description
                              : (AppConstants.expenseCategories[e.category] ?? 'مصروف')),
                          subtitle: Text(
                            '${AppConstants.expenseCategories[e.category] ?? ''}'
                            '${e.workerName != null ? ' - ${e.workerName}' : ''}'
                            ' | ${DateFormat('d/M/yyyy').format(e.date)}',
                          ),
                          trailing: PrivacyBlur(
                            child: Text('${e.amount.toStringAsFixed(0)} ج.م',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 13)),
                          ),
                        ),
                      );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'materials':
        return Icons.inventory_2_rounded;
      case 'rent':
        return Icons.store_rounded;
      case 'wages':
        return Icons.engineering_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }
}
