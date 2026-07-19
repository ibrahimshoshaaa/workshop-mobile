import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/expense_model.dart';
import '../../models/order_model.dart';
import '../../providers/app_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/other_capable_dropdown.dart';

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

  /// الطلبات اللي المصروف ده مقسّم عليها - لو المصروف كان قديم ومرتبط
  /// بطلب واحد بس (orderId) بنحوّله هنا لنفس الشكل الموحّد
  late final Set<String> _selectedOrderIds;

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
    _selectedOrderIds = widget.expense.orderAllocations.isNotEmpty
        ? widget.expense.orderAllocations.map((a) => a.orderId).toSet()
        : (widget.expense.orderId != null ? {widget.expense.orderId!} : <String>{});
  }

  /// ديالوج فيه بحث + قائمة كل الطلبات بعلامات اختيار (Checkbox)، عشان
  /// يختار المستخدم أكتر من طلب في نفس الوقت يتقسم عليهم المصروف
  Future<void> _pickOrders(List<OrderModel> orders) async {
    String query = '';
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final q = query.trim();
          final filtered = q.isEmpty
              ? orders
              : orders.where((o) => o.customerName.contains(q) || o.itemType.contains(q)).toList();
          return AlertDialog(
            title: const Text('اختار الطلبات'),
            content: SizedBox(
              width: double.maxFinite,
              height: 440,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(hintText: 'ابحث بالعميل أو الصنف...', prefixIcon: Icon(Icons.search)),
                    onChanged: (v) => setDialogState(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('لا توجد نتائج', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final o = filtered[index];
                              final checked = _selectedOrderIds.contains(o.id);
                              return CheckboxListTile(
                                value: checked,
                                title: Text('${o.customerName} - ${o.itemType}'),
                                subtitle: Text('${o.status} | المتبقي: ${o.remainingAmount.toStringAsFixed(0)} ج.م'),
                                onChanged: (v) => setDialogState(() {
                                  setState(() {
                                    if (v == true) {
                                      _selectedOrderIds.add(o.id);
                                    } else {
                                      _selectedOrderIds.remove(o.id);
                                    }
                                  });
                                }),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('تم')),
            ],
          );
        },
      ),
    );
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
      final orders = ref.read(ordersStreamProvider).value ?? [];
      final totalAmount = double.parse(_amountController.text.trim());
      final chosenOrders = orders.where((o) => _selectedOrderIds.contains(o.id)).toList();
      final shareAmount = chosenOrders.isEmpty ? 0.0 : totalAmount / chosenOrders.length;
      final orderAllocations = chosenOrders
          .map((o) => ExpenseOrderAllocation(orderId: o.id, customerId: o.customerId, customerName: o.customerName, amount: shareAmount))
          .toList();
      final updated = ExpenseModel(
        id: widget.expense.id,
        amount: totalAmount,
        category: _category,
        description: _descriptionController.text.trim(),
        workerName: _category == 'wages' && _workerNameController.text.trim().isNotEmpty
            ? '${_workerNameController.text.trim()} (${_workerRole ?? ''})'
            : null,
        orderAllocations: orderAllocations,
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
    final orders = ref.watch(ordersStreamProvider).value ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل المصروف')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              OtherCapableDropdown(
                options: AppConstants.expenseCategories.entries
                    .where((e) => e.key != 'other')
                    .map((e) => e.value)
                    .toList(),
                label: 'الفئة',
                value: AppConstants.expenseCategories[_category] ?? _category,
                onChanged: (v) => setState(() {
                  final match = AppConstants.expenseCategories.entries.where((e) => e.value == v).firstOrNull;
                  _category = match?.key ?? v;
                }),
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
                title: const Text('تحميل المصروف على طلبات (اختياري)'),
                subtitle: Text(
                  _selectedOrderIds.isEmpty
                      ? 'مصروف عام - مش مقسّم على أي طلب'
                      : '${_selectedOrderIds.length} طلب مختار - هيتقسم المبلغ عليهم بالتساوي',
                  style: TextStyle(color: _selectedOrderIds.isEmpty ? Colors.grey : null),
                ),
                trailing: const Icon(Icons.checklist_rounded),
                onTap: () => _pickOrders(orders),
              ),
              if (_selectedOrderIds.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _selectedOrderIds.map((id) {
                    final o = orders.where((o) => o.id == id).firstOrNull;
                    return Chip(
                      label: Text(o != null ? '${o.customerName} - ${o.itemType}' : 'طلب محذوف'),
                      onDeleted: () => setState(() => _selectedOrderIds.remove(id)),
                    );
                  }).toList(),
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
