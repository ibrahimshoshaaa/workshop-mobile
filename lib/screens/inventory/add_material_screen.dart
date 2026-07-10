import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/material_item_model.dart';
import '../../providers/app_providers.dart';
import '../../core/constants/app_constants.dart';

/// شاشة واحدة لإضافة خامة جديدة أو تعديل خامة موجودة - لو material اتبعتت
/// من الراوتر يبقى وضع التعديل تلقائيًا
class AddMaterialScreen extends ConsumerStatefulWidget {
  final MaterialItemModel? material;
  const AddMaterialScreen({super.key, this.material});

  @override
  ConsumerState<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends ConsumerState<AddMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _minThresholdController;
  late String _unit;
  bool _isSaving = false;

  bool get _isEditing => widget.material != null;

  @override
  void initState() {
    super.initState();
    final m = widget.material;
    _nameController = TextEditingController(text: m?.name ?? '');
    _quantityController = TextEditingController(text: m != null ? m.quantity.toStringAsFixed(1) : '');
    _minThresholdController = TextEditingController(text: m != null ? m.minThreshold.toStringAsFixed(1) : '');
    _unit = m?.unit ?? AppConstants.materialUnits.first;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final service = ref.read(firebaseServiceProvider);
      final quantity = double.tryParse(_quantityController.text.trim()) ?? 0;
      final minThreshold = double.tryParse(_minThresholdController.text.trim()) ?? 0;

      if (_isEditing) {
        final updated = MaterialItemModel(
          id: widget.material!.id,
          name: _nameController.text.trim(),
          unit: _unit,
          quantity: quantity,
          minThreshold: minThreshold,
          updatedAt: DateTime.now(),
        );
        await service.updateMaterial(updated);
      } else {
        final newMaterial = MaterialItemModel(
          id: '',
          name: _nameController.text.trim(),
          unit: _unit,
          quantity: quantity,
          minThreshold: minThreshold,
          updatedAt: DateTime.now(),
        );
        await service.addMaterial(newMaterial);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الخامة'),
        content: Text('هل أنت متأكد من حذف "${widget.material!.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(firebaseServiceProvider).deleteMaterial(widget.material!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل خامة' : 'إضافة خامة جديدة'),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم الخامة', prefixIcon: Icon(Icons.inventory_2_outlined)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _unit,
                decoration: const InputDecoration(labelText: 'الوحدة'),
                items: AppConstants.materialUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => setState(() => _unit = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'الكمية الحالية', prefixIcon: Icon(Icons.numbers_rounded)),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'أدخل رقم صحيح' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _minThresholdController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'الحد الأدنى للتنبيه',
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                  helperText: 'هيظهر تنبيه لو الكمية وصلت للرقم ده أو أقل',
                ),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'أدخل رقم صحيح' : null,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'حفظ التعديلات' : 'حفظ الخامة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
