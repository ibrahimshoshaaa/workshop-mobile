import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/order_model.dart';
import '../../providers/app_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/notification_service.dart';
class AddOrderScreen extends ConsumerStatefulWidget {
  final String? customerId; // إن جاء من ملف عميل محدد
  const AddOrderScreen({super.key, this.customerId});

  @override
  ConsumerState<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends ConsumerState<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _depositController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _selectedCustomerId;
  String _itemType = AppConstants.itemTypes.first;
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 7));
  bool _isSaving = false;
  final List<XFile> _pickedImages = [];

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.customerId;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _deliveryDate = picked);
  }

  Future<void> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 70, maxWidth: 1600);
      if (images.isNotEmpty) {
        setState(() => _pickedImages.addAll(images));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر فتح المعرض: $e')));
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
      if (photo != null) setState(() => _pickedImages.add(photo));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر فتح الكاميرا: $e')));
      }
    }
  }

  void _removeImage(int index) => setState(() => _pickedImages.removeAt(index));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر العميل أولاً')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final customers = ref.read(customersStreamProvider).value ?? [];
      final customer = customers.firstWhere((c) => c.id == _selectedCustomerId);
      final total = double.tryParse(_totalAmountController.text.trim()) ?? 0;
      final deposit = double.tryParse(_depositController.text.trim()) ?? 0;

      final order = OrderModel(
        id: '',
        customerId: customer.id,
        customerName: customer.name,
        itemType: _itemType,
        details: _detailsController.text.trim(),
        images: const [],
        status: AppConstants.orderStatuses.first,
        totalAmount: total,
        totalPaid: 0,
        deliveryDate: _deliveryDate,
        createdAt: DateTime.now(),
      );

      final service = ref.read(firebaseServiceProvider);
      final orderId = await service.addOrder(order);
      await NotificationService.instance.scheduleOrderDeliveryReminders(
        orderId: orderId,
        customerName: customer.name,
        itemType: order.itemType,
        deliveryDate: order.deliveryDate,
      );
      
   
      // رفع الصور المختارة (لو موجودة) بعد إنشاء الطلب، ثم تحديث حقل images في الطلب
      if (_pickedImages.isNotEmpty) {
        final urls = <String>[];
        for (final img in _pickedImages) {
          final bytes = await img.readAsBytes();
          final url = await service.uploadOrderImageBytes(orderId, bytes);
          urls.add(url);
        }
        await service.updateOrder(order.copyWith(id: orderId, images: urls));
      }

      if (deposit > 0) {
        await service.addPayment(
          orderId: orderId,
          customerId: customer.id,
          amount: deposit,
          paymentType: AppConstants.paymentDeposit,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersStreamProvider).value ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('طلب جديد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCustomerId,
                decoration: const InputDecoration(labelText: 'العميل', prefixIcon: Icon(Icons.person_outline)),
                items: customers
                    .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} - ${c.phone}')))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCustomerId = v),
                validator: (v) => v == null ? 'اختر العميل' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _itemType,
                decoration: const InputDecoration(labelText: 'نوع الصنف', prefixIcon: Icon(Icons.chair_alt_rounded)),
                items: AppConstants.itemTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _itemType = v!),
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
                child: Text('صور التصميم/الخامات (اختياري)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._pickedImages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final img = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(File(img.path), width: 90, height: 90, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
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
                controller: _depositController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'العربون المدفوع الآن (اختياري)', prefixIcon: Icon(Icons.payments_outlined)),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('حفظ الطلب'),
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
