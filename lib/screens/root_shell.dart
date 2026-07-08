import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// الهيكل الرئيسي للتطبيق - يحتوي شريط تنقل سفلي ثابت بين الشاشات الأربع
class RootShell extends StatelessWidget {
  final Widget child;
  const RootShell({super.key, required this.child});

  static const _tabs = [
    ('/dashboard', Icons.dashboard_rounded, 'الرئيسية'),
    ('/customers', Icons.people_alt_rounded, 'العملاء'),
    ('/orders', Icons.checkroom_rounded, 'الطلبات'),
    ('/debts', Icons.account_balance_wallet_rounded, 'المديونيات'),
    ('/expenses', Icons.receipt_long_rounded, 'المصروفات'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _tabs.indexWhere((t) => location.startsWith(t.$1));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(_tabs[index].$1),
        items: _tabs
            .map((t) => BottomNavigationBarItem(icon: Icon(t.$2), label: t.$3))
            .toList(),
      ),
    );
  }
}
