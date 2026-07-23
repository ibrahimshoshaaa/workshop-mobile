import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/worker_model.dart';
import '../../providers/app_providers.dart';
import '../../widgets/privacy_blur.dart';
import '../../widgets/modern_ui.dart';

/// شاشة العمال (صنايعية، محاسبين، مديرين، سوشيال ميديا... أي وظيفة تتضاف
/// وقت إضافة العامل نفسه) - نفس فيتشر تطبيق الديسكتوب بالظبط
class WorkersScreen extends ConsumerStatefulWidget {
  const WorkersScreen({super.key});
  @override
  ConsumerState<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends ConsumerState<WorkersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(workersStreamProvider);
    final dueToday = ref.watch(workersDueTodayProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('العمال')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/workers/add'),
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: ModernSearchField(
              hint: 'ابحث بالاسم أو الوظيفة...',
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          if (dueToday.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'موعد قبض النهاردة: ${dueToday.map((w) => w.name).join('، ')}',
                      style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: workersAsync.when(
              data: (workers) {
                final filtered = _query.isEmpty
                    ? workers
                    : workers
                        .where((w) => w.name.contains(_query) || w.jobTitle.contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return const ModernEmptyState(icon: Icons.groups_outlined, message: 'لا يوجد عمال بعد');
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final w = filtered[index];
                    final isDue = dueToday.any((d) => d.id == w.id);
                    return ModernListCard(
                      onTap: () => _showWorkerDetail(context, ref, w),
                      leading: ModernIconBadge(
                        icon: Icons.engineering_rounded,
                        color: isDue ? AppColors.warning : AppColors.wood,
                        letter: w.name.isNotEmpty ? w.name[0] : '?',
                      ),
                      title: Text(w.name),
                      subtitle: Text(
                        '${w.jobTitle} - ${AppConstants.salaryTypes[w.salaryType]}'
                        '${w.salaryType == 'weekly' ? ' (${AppConstants.weekdayNames[w.payWeekday - 1]})' : ''}',
                      ),
                      trailing: PrivacyBlur(
                        child: Text('${w.salaryAmount.toStringAsFixed(0)} ج.م',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPayment(BuildContext context, WidgetRef ref, WorkerModel worker) async {
    final now = DateTime.now();
    final anchor = workerPeriodAnchor(worker, now);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الدفع'),
        content: Text('هل تم صرف ${worker.salaryAmount.toStringAsFixed(0)} ج.م لـ "${worker.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(firebaseServiceProvider).confirmWorkerPayment(worker: worker, periodStart: anchor);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _showWorkerDetail(BuildContext context, WidgetRef ref, WorkerModel worker) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (dialogContext, ref, _) {
          final payments = ref.watch(workerPaymentsForWorkerProvider(worker.id));
          final now = DateTime.now();
          final paidThisPeriod = isWorkerPaidForCurrentPeriod(worker, payments, now);
          return AlertDialog(
            title: Text(worker.name),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${worker.jobTitle} - ${AppConstants.salaryTypes[worker.salaryType]}'
                        '${worker.salaryType == 'weekly' ? ' (${AppConstants.weekdayNames[worker.payWeekday - 1]})' : ''}'),
                    const SizedBox(height: 4),
                    Text('المرتب: ${worker.salaryAmount.toStringAsFixed(0)} ج.م',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (worker.phone.isNotEmpty) ...[const SizedBox(height: 4), Text('الهاتف: ${worker.phone}')],
                    if (worker.notes.isNotEmpty) ...[const SizedBox(height: 4), Text(worker.notes)],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('سجل القبض', style: Theme.of(dialogContext).textTheme.titleSmall),
                        if (!paidThisPeriod)
                          TextButton.icon(
                            onPressed: () => _confirmPayment(dialogContext, ref, worker),
                            icon: const Icon(Icons.check_circle_outline_rounded),
                            label: const Text('تأكيد قبض الدورة الحالية'),
                          ),
                      ],
                    ),
                    if (payments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('لسه ملوش قبض متسجل', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ...payments.take(10).map((p) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                            title: Text('${p.amount.toStringAsFixed(0)} ج.م'),
                            subtitle: Text(DateFormat('d MMM yyyy', 'ar').format(p.paymentDate)),
                          )),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => context.push('/workers/${worker.id}/edit').then((_) => Navigator.pop(dialogContext)),
                child: const Text('تعديل'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: dialogContext,
                    builder: (context) => AlertDialog(
                      title: const Text('حذف العامل'),
                      content: Text('هل أنت متأكد من حذف "${worker.name}"؟'),
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
                    await ref.read(firebaseServiceProvider).deleteWorker(worker.id);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  }
                },
                child: const Text('حذف'),
              ),
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
            ],
          );
        },
      ),
    );
  }
}
