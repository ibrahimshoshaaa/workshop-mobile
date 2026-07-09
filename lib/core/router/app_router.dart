import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/customers/customers_screen.dart';
import '../../screens/customers/add_customer_screen.dart';
import '../../screens/customers/customer_detail_screen.dart';
import '../../screens/orders/orders_screen.dart';
import '../../screens/orders/add_order_screen.dart';
import '../../screens/orders/order_detail_screen.dart';
import '../../screens/debts/debts_screen.dart';
import '../../screens/expenses/expenses_screen.dart';
import '../../screens/expenses/add_expense_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/root_shell.dart';
import '../auth_state.dart';
import '../../screens/settings/settings_screen.dart';

/// مفتاح عام للراوتر - يُستخدم للتنقل من خارج شجرة الـ Widgets لو احتجناه لاحقًا
final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter? _cachedRouter;

/// الراوتر الرئيسي - يحمي كل الشاشات خلف تسجيل الدخول المحلي البسيط
/// (AuthState.isLoggedIn) بدل Firebase Auth. الدالة دي بترجع نفس النسخة (singleton)
/// في كل مرة عشان الـ listener على AuthState.isLoggedIn مايتكررش لو الواجهة اتبنت تاني.
GoRouter buildAppRouter() {
  return _cachedRouter ??= GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    refreshListenable: AuthState.isLoggedIn,
    redirect: (context, state) {
      final isLoggedIn = AuthState.isLoggedIn.value;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => RootShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddCustomerScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => CustomerDetailScreen(
                  customerId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => AddOrderScreen(
                  customerId: state.uri.queryParameters['customerId'],
                ),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => OrderDetailScreen(
                  orderId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/debts',
            builder: (context, state) => const DebtsScreen(),
          ),
          GoRoute(
            path: '/expenses',
            builder: (context, state) => const ExpensesScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddExpenseScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
        ],
      ),
    ],
  );
}
