import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/privacy_blur.dart';
import '../../widgets/modern_ui.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(filteredExpensesProvider);
    final selectedCategory = ref.watch(expenseCategoryFilterProvider);
    final workerAdvances = ref.watch(workerAdvancesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المصروفات')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.wood,
        onPressed: () => context.push('/expenses/add'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            child: expenses.isEmpty
                ? const ModernEmptyState(icon: Icons.receipt_long_outlined, message: 'لا توجد مصروفات مسجلة')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final e = expenses[index];
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
                    },
                  ),
          ),
        ],
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

