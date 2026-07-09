import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/expense_model.dart';
import '../../providers/app_providers.dart';
import '../../core/constants/app_constants.dart';

class EditExpenseScreen extends ConsumerStatefulWidget {
  final ExpenseModel expense;
  const EditExpenseScreen({super.key, required this.expense});

  @override
  ConsumerState<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends ConsumerState<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _workerNameController;

  late String _category;
  String? _workerRole;
  late DateTime _date;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.expense.category;
    _date = widget.expense.date;
    _amountController = TextEditingController(text: widget.expense.amount.toStringAsFixed(0));
    _descriptionController = TextEditingController(text: widget.expense.description);
    // اسم الصنايعي والتخصص متخزّنين مع بعض كـ "الاسم (التخصص)" - نفصلهم هنا لو موجودين
    final workerName = widget.expense.workerName ?? '';
    final match = RegExp(r'^(.*) \((.*)\)$').firstMatch(workerName);
    _workerNameController = TextEditingController(text: match?.group(1) ?? workerName);
    _workerRole = match?.group(2);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final updated = ExpenseModel(
        id: widget.expense.id,
        amount: double.parse(_amountController.text.trim()),
        category: _category,
        description: _descriptionController.text.trim(),
        workerName: _category == 'wages' && _workerNameController.text.trim().isNotEmpty
            ? '${_workerNameController.text.trim()} (${_workerRole ?? ''})'
            : null,
        date: _date,
      );
      await ref.read(firebaseServiceProvider).updateExpense(updated);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWages = _category == 'wages';
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل المصروف')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'الفئة'),
                items: AppConstants.expenseCategories.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 16),
              if (isWages) ...[
                TextFormField(
                  controller: _workerNameController,
                  decoration: const InputDecoration(labelText: 'اسم الصنايعي', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => isWages && (v == null || v.trim().isEmpty) ? 'اسم الصنايعي مطلوب' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _workerRole,
                  decoration: const InputDecoration(labelText: 'التخصص'),
                  items: AppConstants.workerRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setState(() => _workerRole = v),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ (ج.م)', prefixIcon: Icon(Icons.attach_money_rounded)),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'أدخل مبلغ صحيح' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'الوصف (اختياري)'),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('التاريخ'),
                subtitle: Text('${_date.year}/${_date.month}/${_date.day}'),
                trailing: const Icon(Icons.calendar_month_rounded),
                onTap: _pickDate,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('حفظ التعديلات'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
