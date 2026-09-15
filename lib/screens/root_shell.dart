import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth_state.dart';
import '../core/theme/app_theme.dart';

/// الهيكل الرئيسي للتطبيق - يحتوي شريط تنقل سفلي بين الشاشات المسموح
/// بيها لليوزر الحالي بس. الرئيسية متاحة دايمًا للكل.
class RootShell extends StatefulWidget {
  final Widget child;
  const RootShell({super.key, required this.child});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  static const _allTabs = [
    ('/dashboard', Icons.dashboard_rounded, 'الرئيسية', null),
    ('/customers', Icons.people_alt_rounded, 'العملاء', 'customers'),
    ('/orders', Icons.checkroom_rounded, 'الطلبات', 'orders'),
    ('/debts', Icons.account_balance_wallet_rounded, 'المديونيات', 'debts'),
    ('/expenses', Icons.menu_rounded, 'أقسام', 'expenses'),
  ];

  static const _moreItems = [
    ('/expenses', Icons.receipt_long_rounded, 'المصروفات', 'expenses'),
    ('/workers', Icons.groups_rounded, 'العمال', 'workers'),
    ('/workshop-debts', Icons.storefront_rounded, 'مديونيات الورشة', 'debts'),
    ('/inventory', Icons.inventory_2_rounded, 'المخزون', 'inventory'),
    ('/reports', Icons.bar_chart_rounded, 'التقارير', 'reports'),
    ('/customer-archive', Icons.archive_rounded, 'أرشيف العملاء', 'admin'),
  ];

  @override
  void initState() {
    super.initState();
    AuthState.refreshCurrentUserPermissions();
  }

  bool _canOpen(String permission) => permission == 'admin' ? AuthState.isAdmin : AuthState.can(permission);

  int _currentIndex(BuildContext context, List tabs) {
    final location = GoRouterState.of(context).uri.toString();
    final isInMoreGroup = _moreItems.any((m) => location.startsWith(m.$1));
    if (isInMoreGroup) {
      final expensesIndex = tabs.indexWhere((t) => t.$1 == '/expenses');
      if (expensesIndex != -1) return expensesIndex;
    }
    final index = tabs.indexWhere((t) => location.startsWith(t.$1 as String));
    return index == -1 ? 0 : index;
  }

  Future<void> _openMoreMenu(BuildContext context) async {
    final items = _moreItems.where((m) => _canOpen(m.$4)).toList();
    if (items.isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _MoreMenuSheet(items: items),
    );
    if (selected != null && context.mounted) context.go(selected);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AuthState.permissionsVersion,
      builder: (context, _, __) {
        final tabs = _allTabs.where((t) {
          if (t.$1 == '/expenses') {
            return _moreItems.any((m) => _canOpen(m.$4));
          }
          return t.$4 == null || AuthState.can(t.$4!);
        }).toList();
        final currentIndex = _currentIndex(context, tabs);
        return Scaffold(
          body: widget.child,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) {
              final tappedPath = tabs[index].$1 as String;
              if (tappedPath == '/expenses') {
                _openMoreMenu(context);
              } else {
                context.go(tappedPath);
              }
            },
            items: tabs.map((t) => BottomNavigationBarItem(icon: Icon(t.$2), label: t.$3)).toList(),
          ),
        );
      },
    );
  }
}

class _MoreMenuSheet extends StatefulWidget {
  final List<(String, IconData, String, String)> items;
  const _MoreMenuSheet({required this.items});

  @override
  State<_MoreMenuSheet> createState() => _MoreMenuSheetState();
}

class _MoreMenuSheetState extends State<_MoreMenuSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, i) {
                  final item = widget.items[i];
                  final start = i * 0.12;
                  final end = (start + 0.55).clamp(0.0, 1.0);
                  final curved = CurvedAnimation(parent: _controller, curve: Interval(start, end, curve: Curves.easeOutBack));
                  return AnimatedBuilder(
                    animation: curved,
                    builder: (context, child) => Opacity(
                      opacity: curved.value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - curved.value.clamp(0.0, 1.0))),
                        child: child,
                      ),
                    ),
                    child: _MoreMenuItem(
                      icon: item.$2,
                      label: item.$3,
                      onTap: () => Navigator.of(context).pop(item.$1),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MoreMenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.wood.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.wood),
          ),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
