import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/customer_archive_providers.dart';
import '../../services/customer_archive_service.dart';
import '../../core/auth_state.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/modern_ui.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(combinedCustomerSearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('العملاء')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.wood,
        onPressed: () => context.push('/customers/add'),
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: ModernSearchField(
              hint: 'ابحث بالاسم أو رقم الهاتف أو الرقم التسلسلي...',
              onChanged: (v) => ref.read(customerArchiveSearchProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: customers.isEmpty
                ? const ModernEmptyState(icon: Icons.people_outline_rounded, message: 'لا يوجد عملاء مطابقون')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final c = customers[index];
                      final archived = c.isArchived;
                      return ModernListCard(
                        backgroundColor: archived ? Colors.grey.withOpacity(0.06) : null,
                        leading: ModernIconBadge(
                          icon: archived ? Icons.inventory_2_outlined : Icons.person_rounded,
                          color: archived ? Colors.grey : AppColors.wood,
                          letter: c.name.isNotEmpty ? c.name[0] : '?',
                        ),
                        title: Row(
                          children: [
                            Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: archived ? Colors.grey.withOpacity(0.12) : AppColors.wood.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                archived ? 'مؤرشف' : '#${c.serialNumber}',
                                style: TextStyle(fontSize: 11, color: archived ? Colors.grey : AppColors.wood, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          archived
                              ? '${c.phone} • أرشيف ${c.archiveYear ?? ''} • اضغط لفتح الأرشيف'
                              : c.phone,
                        ),
                        trailing: archived
                            ? OutlinedButton(
                                onPressed: () => context.push('/customer-archive'),
                                child: const Text('فتح الأرشيف'),
                              )
                            : const Icon(Icons.chevron_left_rounded, color: Colors.grey),
                        onTap: archived ? () => context.push('/customer-archive') : () => context.push('/customers/${c.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
