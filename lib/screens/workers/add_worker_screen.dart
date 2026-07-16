import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../models/worker_model.dart';
import '../../providers/app_providers.dart';

/// شاشة إضافة/تعديل عامل - نفس حقول ديالوج الديسكتوب (اسم، وظيفة، نوع
/// المرتب، يوم القبض لو أسبوعي، المبلغ، هاتف، ملاحظات)
class AddWorkerScreen extends ConsumerStatefulWidget {
  final WorkerModel? worker;
  const AddWorkerScreen({super.key, this.worker});

  @override
  ConsumerState<AddWorkerScreen> createState() => _AddWorkerScreenState();
}

class _AddWorkerScreenState extends ConsumerState<AddWorkerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.worker?.name ?? '');
  late final _jobController = TextEditingController(text: widget.worker?.jobTitle ?? '');
  late final _amountController =
      TextEditingController(text: widget.worker != null ? widget.worker!.salaryAmount.toStringAsFixed(0) : '');
  late final _phoneController = TextEditingController(text: widget.worker?.phone ?? '');
  late final _notesController = TextEditingController(text: widget.worker?.notes ?? '');
  late String _salaryType = widget.worker?.salaryType ?? 'monthly';
  late int _payWeekday = widget.worker?.payWeekday ?? DateTime.thursday;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _jobController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final service = ref.read(firebaseServiceProvider);
      if (widget.worker == null) {
        final worker = WorkerModel(
          id: '',
          name: _nameController.text.trim(),
          jobTitle: _jobController.text.trim(),
          salaryType: _salaryType,
          salaryAmount: double.parse(_amountController.text),
          payWeekday: _payWeekday,
          phone: _phoneController.text.trim(),
          notes: _notesController.text.trim(),
          createdAt: DateTime.now(),
        );
        await service.addWorker(worker);
      } else {
        final updated = widget.worker!.copyWith(
          name: _nameController.text.trim(),
          jobTitle: _jobController.text.trim(),
          salaryType: _salaryType,
          salaryAmount: double.parse(_amountController.text),
          payWeekday: _payWeekday,
          phone: _phoneController.text.trim(),
          notes: _notesController.text.trim(),
        );
        await service.updateWorker(updated);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.worker != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل بيانات العامل' : 'إضافة عامل جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم العامل'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _jobController,
              decoration: const InputDecoration(labelText: 'الوظيفة (صنايعي، محاسب، سوشيال ميديا...)'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'الوظيفة مطلوبة' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _salaryType,
              decoration: const InputDecoration(labelText: 'نوع المرتب'),
              items: AppConstants.salaryTypes.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _salaryType = v!),
            ),
            if (_salaryType == 'weekly') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _payWeekday,
                decoration: const InputDecoration(labelText: 'يوم القبض الأسبوعي'),
                items: List.generate(7, (i) => i + 1)
                    .map((d) => DropdownMenuItem(value: d, child: Text(AppConstants.weekdayNames[d - 1])))
                    .toList(),
                onChanged: (v) => setState(() => _payWeekday = v!),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _salaryType == 'monthly'
                    ? 'المرتب الشهري (ج.م)'
                    : _salaryType == 'weekly'
                        ? 'المرتب الأسبوعي (ج.م)'
                        : 'المرتب اليومي (ج.م)',
              ),
              validator: (v) => (v == null || double.tryParse(v) == null) ? 'أدخل مبلغ صحيح' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'حفظ التعديلات' : 'إضافة العامل'),
            ),
          ],
        ),
      ),
    );
  }
}
