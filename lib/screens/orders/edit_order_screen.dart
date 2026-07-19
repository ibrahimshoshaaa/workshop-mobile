import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/order_model.dart';
import '../../providers/app_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/notification_service.dart';
import '../../widgets/other_capable_dropdown.dart';

class EditOrderScreen extends ConsumerStatefulWidget {
  final OrderModel order;
  const EditOrderScreen({super.key, required this.order});

  @override
  ConsumerState<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends ConsumerState<EditOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _detailsController;
  late final TextEditingController _totalAmountController;
  late final TextEditingController _discountController;
  late final TextEditingController _discountReasonController;
  final _imagePicker = ImagePicker();

  late String _itemType;
  late DateTime _deliveryDate;
  bool _isSaving = false;
  late List<String> _existingImageUrls;
  final List<String> _removedImageUrls = [];
  final List<XFile> _newImages = [];

  @override
  void initState() {
    super.initState();
    _itemType = widget.order.itemType;
    _deliveryDate = widget.order.deliveryDate;
    _detailsController = TextEditingController(text: widget.order.details);
    _totalAmountController = TextEditingController(text: widget.order.totalAmount.toStringAsFixed(0));
    _discountController = TextEditingController(
      text: widget.order.discountAmount > 0 ? widget.order.discountAmount.toStringAsFixed(0) : '',
    );
    _discountReasonController = TextEditingController(text: widget.order.discountReason);
    _existingImageUrls = List.of(widget.order.images);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _deliveryDate = picked);
  }

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 70, maxWidth: 1600);
      if (images.isNotEmpty) setState(() => _newImages.addAll(images));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر فتح المعرض: $e')));
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
      if (photo != null) setState(() => _newImages.add(photo));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر فتح الكاميرا: $e')));
    }
  }

  void _removeExistingImage(String url) {
    setState(() {
      _existingImageUrls.remove(url);
      _removedImageUrls.add(url);
    });
  }

  void _removeNewImage(int index) => setState(() => _newImages.removeAt(index));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final service = ref.read(firebaseServiceProvider);
      final total = double.tryParse(_totalAmountController.text.trim()) ?? widget.order.totalAmount;

      // ارفع أي صور جديدة اتضافت (لو صورة فشلت بنتخطاها من غير ما نوقف الحفظ)
      final uploadedUrls = <String>[];
      var failedCount = 0;
      for (final img in _newImages) {
        try {
          final bytes = await img.readAsBytes();
          final url = await service.uploadOrderImageBytes(widget.order.id, bytes);
          uploadedUrls.add(url);
        } catch (_) {
          failedCount++;
        }
      }

      // احذف الصور اللي اتشالت من Storage
      for (final url in _removedImageUrls) {
        await service.deleteOrderImageByUrl(url);
      }

      final updated = widget.order.copyWith(
        itemType: _itemType,
        details: _detailsController.text.trim(),
        images: [..._existingImageUrls, ...uploadedUrls],
        totalAmount: total,
        discountAmount: double.tryParse(_discountController.text.trim()) ?? 0,
        discountReason: _discountReasonController.text.trim(),
        deliveryDate: _deliveryDate,
      );
      await service.updateOrder(updated);
      if (failedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر رفع $failedCount صورة - باقي التعديلات اتحفظت عادي')),
        );
      }
      await NotificationService.instance.scheduleOrderDeliveryReminders(
        orderId: widget.order.id,
        customerName: widget.order.customerName,
        itemType: updated.itemType,
        deliveryDate: updated.deliveryDate,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الطلب')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              OtherCapableDropdown(
                options: AppConstants.itemTypes.where((t) => t != kOtherOptionValue).toList(),
                label: 'نوع الصنف',
                value: _itemType,
                onChanged: (v) => setState(() => _itemType = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'المواصفات (نوع القماش، الخشب، الأبعاد، كثافة الإسفنج)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text('الصور', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._existingImageUrls.map((url) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(url, width: 90, height: 90, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeExistingImage(url),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    ..._newImages.asMap().entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(File(entry.value.path), width: 90, height: 90, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeNewImage(entry.key),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    _AddImageButton(icon: Icons.photo_library_outlined, label: 'المعرض', onTap: _pickImages),
                    const SizedBox(width: 8),
                    _AddImageButton(icon: Icons.camera_alt_outlined, label: 'كاميرا', onTap: _takePhoto),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تاريخ التسليم المتوقع'),
                subtitle: Text('${_deliveryDate.year}/${_deliveryDate.month}/${_deliveryDate.day}'),
                trailing: const Icon(Icons.calendar_month_rounded),
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _totalAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'إجمالي الاتفاق (ج.م)', prefixIcon: Icon(Icons.attach_money_rounded)),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'أدخل مبلغ صحيح' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'خصم بمبلغ ثابت (اختياري)',
                  prefixIcon: Icon(Icons.percent_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _discountReasonController,
                decoration: const InputDecoration(labelText: 'سبب الخصم (اختياري)'),
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

class _AddImageButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AddImageButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.wood),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
