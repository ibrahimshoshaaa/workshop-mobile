import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

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
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم أو رقم الهاتف...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => ref.read(customerSearchQueryProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: customers.isEmpty
                ? const Center(child: Text('لا يوجد عملاء بعد', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final c = customers[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.wood.withOpacity(0.15),
                            child: Text(c.name.isNotEmpty ? c.name[0] : '?',
                                style: const TextStyle(color: AppColors.wood, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(c.phone),
                          trailing: const Icon(Icons.chevron_left_rounded),
                          onTap: () => context.push('/customers/${c.id}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
