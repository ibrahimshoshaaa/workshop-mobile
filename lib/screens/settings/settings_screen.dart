import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth_state.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showAddUserDialog(BuildContext context, WidgetRef ref, List<String> existingUsernames) async {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة حساب جديد'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: usernameController,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'اليوزر'),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'اكتب اليوزر';
                    if (value == 'admin') return 'الاسم ده محجوز للحساب الرئيسي';
                    if (existingUsernames.contains(value)) return 'اليوزر ده موجود بالفعل';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'الباسورد'),
                  validator: (v) =>
                      (v == null || v.length < 4) ? 'الباسورد لازم يكون 4 حروف/أرقام على الأقل' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(firebaseServiceProvider).addUser(
                              usernameController.text.trim(),
                              passwordController.text,
                            );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                        }
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(
      BuildContext context, WidgetRef ref, String userId, String username) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('تغيير باسورد "$username"'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'الباسورد الجديد'),
              validator: (v) => (v == null || v.length < 4) ? 'الباسورد لازم يكون 4 حروف/أرقام على الأقل' : null,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(firebaseServiceProvider).updateUserPassword(userId, controller.text);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                        }
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(appUsersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_rounded, color: AppColors.wood),
                  title: const Text('العمال'),
                  subtitle: const Text('المرتبات والقبض الدوري'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => context.push('/workers'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.handshake_rounded, color: AppColors.woodDark),
                  title: const Text('ديون الورشة'),
                  subtitle: const Text('مستحقات الموردين والصنايعية'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => context.push('/workshop-debts'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.inventory_2_rounded, color: AppColors.amber),
                  title: const Text('المخزون'),
                  subtitle: const Text('الخامات والحد الأدنى'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => context.push('/inventory'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bar_chart_rounded, color: AppColors.navy),
                  title: const Text('التقارير'),
                  subtitle: const Text('الإيرادات والتحليلات'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => context.push('/reports'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: AppColors.wood),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('مسجّل دخول كـ: ${AuthState.currentUsername ?? '-'}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          'الحساب الرئيسي (admin) ثابت دايمًا كخط أمان، متقدرش تتغيّر أو تتحذف من هنا',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('حسابات إضافية (عمال)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              usersAsync.when(
                data: (users) => TextButton.icon(
                  onPressed: () => _showAddUserDialog(context, ref, users.map((u) => u.username).toList()),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('إضافة'),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          usersAsync.when(
            data: (users) {
              if (users.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('لا توجد حسابات إضافية بعد', style: TextStyle(color: Colors.grey))),
                );
              }
              return Column(
                children: users.map((u) {
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.wood.withValues(alpha: 0.15),
                        child: Text(u.username.isNotEmpty ? u.username[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.wood, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(u.username, textDirection: TextDirection.ltr),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.lock_reset_rounded),
                            tooltip: 'تغيير الباسورد',
                            onPressed: () => _showChangePasswordDialog(context, ref, u.id, u.username),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                            tooltip: 'حذف الحساب',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('حذف الحساب'),
                                  content: Text('هل أنت متأكد من حذف حساب "${u.username}"؟'),
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
                                await ref.read(firebaseServiceProvider).deleteUser(u.id);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
          ),
        ],
      ),
    );
  }
}
