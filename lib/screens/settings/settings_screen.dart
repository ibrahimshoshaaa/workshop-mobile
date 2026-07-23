import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_state.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_account_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/theme_mode_provider.dart';
import '../../widgets/modern_ui.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showAddUserDialog(BuildContext context, WidgetRef ref, List<String> existingUsernames) async {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSaving = false;
    final permissions = <String, bool>{
      for (final s in UserAccountModel.permissionScreens) s.key: true,
    };

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة حساب جديد'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const Divider(height: 24),
                    const Text('الأقسام المسموح بيها', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...UserAccountModel.permissionScreens.map((s) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(s.value),
                          value: permissions[s.key],
                          activeColor: AppColors.wood,
                          onChanged: (v) => setDialogState(() => permissions[s.key] = v ?? true),
                        )),
                  ],
                ),
              ),
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
                              permissions: permissions,
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

  Future<void> _showEditPermissionsDialog(BuildContext context, WidgetRef ref, UserAccountModel user) async {
    bool isSaving = false;
    final permissions = <String, bool>{
      for (final s in UserAccountModel.permissionScreens) s.key: user.canAccess(s.key),
    };

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('صلاحيات "${user.username}"'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: UserAccountModel.permissionScreens
                    .map((s) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(s.value),
                          value: permissions[s.key],
                          activeColor: AppColors.wood,
                          onChanged: (v) => setDialogState(() => permissions[s.key] = v ?? true),
                        ))
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        await ref.read(firebaseServiceProvider).updateUserPermissions(user.id, permissions);
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

  /// Firebase Authentication (من غير Cloud Functions/Admin SDK) مبيسمحش
  /// لأي حساب - حتى الأدمن - يغيّر باسورد حساب تاني غير حسابه هو مباشرة.
  /// ده قيد حقيقي في تصميم Firebase نفسه، مش نقص في التطبيق. الحل الوحيد
  /// المتاح دلوقتي: احذف الحساب وأضيفه تاني بباسورد جديد (المسح بيقفل
  /// دخوله على التطبيق فورًا حتى لو حسابه في Firebase Auth لسه موجود فعليًا،
  /// لأن التطبيق مش هيلاقيله سجل صلاحيات فيرفضله الدخول تلقائيًا).
  Future<void> _showChangePasswordInfoDialog(BuildContext context, String username) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تغيير باسورد "$username"'),
        content: const Text(
          'مش ممكن نغيّر باسورد حساب عامل تاني مباشرة (قيد أماني حقيقي في '
          'Firebase نفسه، مش نقص في التطبيق).\n\n'
          'البديل: احذف الحساب من هنا، وضيفه تاني بيوزرنيم وباسورد جديدين. '
          'الحذف بيقفل دخوله على التطبيق فورًا.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('تمام')),
        ],
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
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ModernIconBadge(icon: Icons.dark_mode_rounded, color: AppColors.wood, size: 40),
                      const SizedBox(width: 12),
                      Text('مظهر التطبيق', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Consumer(
                    builder: (context, ref, _) {
                      final themeMode = ref.watch(appThemeModeProvider);
                      return SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('فاتح')),
                          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('غامق')),
                          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.smartphone_rounded), label: Text('حسب الجهاز')),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (selection) => ref.read(appThemeModeProvider.notifier).setMode(selection.first),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const ModernIconBadge(icon: Icons.verified_user_rounded, color: AppColors.wood, size: 40),
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
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: ModernEmptyState(icon: Icons.group_outlined, message: 'لا توجد حسابات إضافية بعد'),
                );
              }
              return Column(
                children: users.map((u) {
                  final allowedScreens = UserAccountModel.permissionScreens.where((s) => u.canAccess(s.key)).toList();
                  final permissionsSubtitle = allowedScreens.length == UserAccountModel.permissionScreens.length
                      ? 'كل الأقسام مسموحة'
                      : allowedScreens.isEmpty
                          ? 'مفيش أقسام مسموحة'
                          : allowedScreens.map((s) => s.value).join('، ');
                  return ModernListCard(
                    leading: ModernIconBadge(
                      icon: Icons.person_rounded,
                      color: AppColors.wood,
                      letter: u.username.isNotEmpty ? u.username[0].toUpperCase() : '?',
                    ),
                    title: Text(u.username, textDirection: TextDirection.ltr),
                    subtitle: Text(permissionsSubtitle),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.checklist_rounded, size: 20),
                          tooltip: 'تعديل الصلاحيات',
                          onPressed: () => _showEditPermissionsDialog(context, ref, u),
                        ),
                        IconButton(
                          icon: const Icon(Icons.lock_reset_rounded, size: 20),
                          tooltip: 'تغيير الباسورد',
                          onPressed: () => _showChangePasswordInfoDialog(context, u.username),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
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
