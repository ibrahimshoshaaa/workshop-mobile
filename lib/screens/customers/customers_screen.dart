import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/modern_ui.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(filteredCustomersProvider);

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
              hint: 'ابحث بالاسم أو رقم الهاتف...',
              onChanged: (v) => ref.read(customerSearchQueryProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: customers.isEmpty
                ? const ModernEmptyState(icon: Icons.people_outline_rounded, message: 'لا يوجد عملاء بعد')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final c = customers[index];
                      return ModernListCard(
                        leading: ModernIconBadge(
                          icon: Icons.person_rounded,
                          color: AppColors.wood,
                          letter: c.name.isNotEmpty ? c.name[0] : '?',
                        ),
                        title: Row(
                          children: [
                            Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.wood.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '#${c.serialNumber}',
                                style: const TextStyle(fontSize: 11, color: AppColors.wood, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(c.phone),
                        trailing: const Icon(Icons.chevron_left_rounded, color: Colors.grey),
                        onTap: () => context.push('/customers/${c.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
