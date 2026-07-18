import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth_state.dart';

/// الهيكل الرئيسي للتطبيق - يحتوي شريط تنقل سفلي بين الشاشات المسموح
/// بيها لليوزر الحالي بس. الرئيسية متاحة دايمًا للكل.
class RootShell extends StatefulWidget {
  final Widget child;
  const RootShell({super.key, required this.child});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  // كل تاب مرتبط بمفتاح الصلاحية بتاعه. null = متاح للكل دايمًا.
  static const _allTabs = [
    ('/dashboard', Icons.dashboard_rounded, 'الرئيسية', null),
    ('/customers', Icons.people_alt_rounded, 'العملاء', 'customers'),
    ('/orders', Icons.checkroom_rounded, 'الطلبات', 'orders'),
    ('/debts', Icons.account_balance_wallet_rounded, 'المديونيات', 'debts'),
    ('/expenses', Icons.receipt_long_rounded, 'المصروفات', 'expenses'),
  ];

  @override
  void initState() {
    super.initState();
    // لو الأدمن غيّر صلاحيات اليوزر ده وهو مسجل خروج، التحديث يوصله أول
    // ما يفتح التطبيق تاني من غير ما يحتاج يعمل تسجيل دخول من الأول
    AuthState.refreshCurrentUserPermissions();
  }

  int _currentIndex(BuildContext context, List tabs) {
    final location = GoRouterState.of(context).uri.toString();
    final index = tabs.indexWhere((t) => location.startsWith(t.$1 as String));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AuthState.permissionsVersion,
      builder: (context, _, __) {
        final tabs = _allTabs.where((t) => t.$4 == null || AuthState.can(t.$4!)).toList();
        final currentIndex = _currentIndex(context, tabs);
        return Scaffold(
          body: widget.child,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) => context.go(tabs[index].$1),
            items: tabs
                .map((t) => BottomNavigationBarItem(icon: Icon(t.$2), label: t.$3))
                .toList(),
          ),
        );
      },
    );
  }
}
