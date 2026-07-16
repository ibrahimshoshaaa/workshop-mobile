import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/workshop_debt_model.dart';
import '../../providers/app_providers.dart';
import '../../widgets/privacy_blur.dart';

/// شاشة "ديون الورشة" - الديون اللي على الورشة لصالح الموردين أو
/// الصنايعية (عكس شاشة "المديونيات" اللي هي فلوس لينا عند العملاء)
class WorkshopDebtsScreen extends ConsumerWidget {
  const WorkshopDebtsScreen({super.key});

  Future<void> _showDebtDialog(BuildContext context, WidgetRef ref, {WorkshopDebtModel? debt}) async {
    final formKey = GlobalKey<FormState>();
    final creditorController = TextEditingController(text: debt?.creditorName ?? '');
    final amountController = TextEditingController(text: debt != null ? debt.totalAmount.toStringAsFixed(0) : '');
    final notesController = TextEditingController(text: debt?.notes ?? '');
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(debt == null ? 'إضافة مديونية جديدة' : 'تعديل المديونية'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: creditorController,
                    decoration: const InputDecoration(labelText: 'اسم المورد/الصنايعي'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'إجمالي المديونية (ج.م)'),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? 'أدخل مبلغ صحيح' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        final service = ref.read(firebaseServiceProvider);
                        if (debt == null) {
                          await service.addWorkshopDebt(WorkshopDebtModel(
                            id: '',
                            creditorName: creditorController.text.trim(),
                            totalAmount: double.parse(amountController.text),
                            notes: notesController.text.trim(),
                            createdAt: DateTime.now(),
                          ));
                        } else {
                          await service.updateWorkshopDebt(debt.copyWith(
                            creditorName: creditorController.text.trim(),
                            totalAmount: double.parse(amountController.text),
                            notes: notesController.text.trim(),
                          ));
                        }
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                        }
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPayDialog(BuildContext context, WidgetRef ref, WorkshopDebtModel debt) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    String paymentMethod = 'cash';
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('سداد لـ "${debt.creditorName}"'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المتبقي: ${debt.remainingAmount.toStringAsFixed(0)} ج.م', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ المسدد (ج.م)'),
                  validator: (v) {
                    final value = double.tryParse(v ?? '');
                    if (value == null || value <= 0) return 'أدخل مبلغ صحيح';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration: const InputDecoration(labelText: 'طريقة السداد'),
                  items: AppConstants.paymentMethods.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => paymentMethod = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(firebaseServiceProvider).payWorkshopDebt(
                              debt: debt,
                              amount: double.parse(amountController.text),
                              paymentMethod: paymentMethod,
                            );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                        }
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('تأكيد السداد'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, WorkshopDebtModel debt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المديونية'),
        content: Text('هل أنت متأكد من حذف مديونية "${debt.creditorName}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(firebaseServiceProvider).deleteWorkshopDebt(debt.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(workshopDebtsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ديون الورشة')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDebtDialog(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
      body: debtsAsync.when(
        data: (debts) {
          if (debts.isEmpty) {
            return const Center(child: Text('لا توجد ديون على الورشة حاليًا 🎉', style: TextStyle(color: Colors.grey)));
          }
          final sorted = [...debts]..sort((a, b) => b.remainingAmount.compareTo(a.remainingAmount));
          final totalRemaining = debts.fold<double>(0, (sum, d) => sum + d.remainingAmount);
          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.woodDark.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    const Text('إجمالي المتبقي للموردين/الصنايعية', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 6),
                    PrivacyBlur(
                      child: Text('${totalRemaining.toStringAsFixed(0)} ج.م',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.woodDark)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final d = sorted[index];
                    final isPaid = d.isFullyPaid;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (isPaid ? AppColors.success : AppColors.woodDark).withOpacity(0.15),
                          child: Icon(isPaid ? Icons.check_rounded : Icons.priority_high_rounded,
                              color: isPaid ? AppColors.success : AppColors.woodDark),
                        ),
                        title: Text(d.creditorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'الإجمالي: ${d.totalAmount.toStringAsFixed(0)} ج.م - المسدد: ${d.paidAmount.toStringAsFixed(0)} ج.م',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PrivacyBlur(
                              child: Text(
                                isPaid ? 'مسدد' : '${d.remainingAmount.toStringAsFixed(0)} ج.م',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isPaid ? AppColors.success : AppColors.woodDark,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'pay') _showPayDialog(context, ref, d);
                                if (value == 'edit') _showDebtDialog(context, ref, debt: d);
                                if (value == 'delete') _confirmDelete(context, ref, d);
                              },
                              itemBuilder: (context) => [
                                if (!isPaid) const PopupMenuItem(value: 'pay', child: Text('سداد')),
                                const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                const PopupMenuItem(value: 'delete', child: Text('حذف')),
                              ],
                            ),
                          ],
                        ),
                        onTap: isPaid ? null : () => _showPayDialog(context, ref, d),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}
