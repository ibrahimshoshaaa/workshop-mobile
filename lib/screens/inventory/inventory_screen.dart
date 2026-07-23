import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/material_item_model.dart';
import '../../widgets/modern_ui.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  Future<void> _showAdjustDialog(BuildContext context, WidgetRef ref, MaterialItemModel item) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الكمية الحالية: ${item.quantity.toStringAsFixed(1)} ${item.unit}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: const InputDecoration(
                labelText: 'الكمية (+ للإضافة، - للخصم)',
                hintText: 'مثال: 5 أو -3',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final delta = double.tryParse(controller.text.trim());
              if (delta == null || delta == 0) return;
              await ref.read(firebaseServiceProvider).adjustMaterialQuantity(item.id, delta);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(materialsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('مخزون الخامات')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.wood,
        onPressed: () => context.push('/inventory/add'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: materialsAsync.when(
        data: (materials) {
          if (materials.isEmpty) {
            return const ModernEmptyState(icon: Icons.inventory_2_outlined, message: 'لا توجد خامات مسجلة بعد');
          }
          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: AppColors.wood.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: AppColors.wood.withOpacity(0.8)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'اضغط على أي خامة عشان تحدّث الكمية بسرعة، أو اضغط مطولًا للتعديل الكامل',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: materials.length,
                  itemBuilder: (context, index) {
                    final m = materials[index];
                    return ModernListCard(
                      backgroundColor: m.isLow ? AppColors.danger.withValues(alpha: 0.06) : null,
                      onTap: () => _showAdjustDialog(context, ref, m),
                      onLongPress: () => context.push('/inventory/${m.id}/edit'),
                      leading: ModernIconBadge(
                        icon: Icons.inventory_2_rounded,
                        color: m.isLow ? AppColors.danger : AppColors.wood,
                      ),
                      title: Text(m.name),
                      subtitle: Text('الحد الأدنى: ${m.minThreshold.toStringAsFixed(1)} ${m.unit}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${m.quantity.toStringAsFixed(1)} ${m.unit}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: m.isLow ? AppColors.danger : AppColors.success)),
                          if (m.isLow)
                            const Text('على وشك النفاد', style: TextStyle(fontSize: 11, color: AppColors.danger)),
                        ],
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
