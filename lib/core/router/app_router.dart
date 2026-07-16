import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/customers/customers_screen.dart';
import '../../screens/customers/add_customer_screen.dart';
import '../../screens/customers/edit_customer_screen.dart';
import '../../screens/customers/customer_detail_screen.dart';
import '../../screens/orders/orders_screen.dart';
import '../../screens/orders/add_order_screen.dart';
import '../../screens/orders/edit_order_screen.dart';
import '../../screens/orders/order_detail_screen.dart';
import '../../screens/debts/debts_screen.dart';
import '../../screens/expenses/expenses_screen.dart';
import '../../screens/expenses/add_expense_screen.dart';
import '../../screens/expenses/edit_expense_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/reports/revenue_detail_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/inventory/inventory_screen.dart';
import '../../screens/inventory/add_material_screen.dart';
import '../../screens/workers/workers_screen.dart';
import '../../screens/workers/add_worker_screen.dart';
import '../../screens/debts/workshop_debts_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/root_shell.dart';
import '../auth_state.dart';
import '../../providers/app_providers.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter? _cachedRouter;

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
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final customerId = state.pathParameters['id']!;
                      return Consumer(
                        builder: (context, ref, _) {
                          final customers = ref.watch(customersStreamProvider).value ?? [];
                          final customer = customers.where((c) => c.id == customerId).firstOrNull;
                          if (customer == null) {
                            return const Scaffold(body: Center(child: Text('العميل غير موجود')));
                          }
                          return EditCustomerScreen(customer: customer);
                        },
                      );
                    },
                  ),
                ],
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
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final orderId = state.pathParameters['id']!;
                      return Consumer(
                        builder: (context, ref, _) {
                          final orders = ref.watch(ordersStreamProvider).value ?? [];
                          final order = orders.where((o) => o.id == orderId).firstOrNull;
                          if (order == null) {
                            return const Scaffold(body: Center(child: Text('الطلب غير موجود')));
                          }
                          return EditOrderScreen(order: order);
                        },
                      );
                    },
                  ),
                ],
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
              GoRoute(
                path: ':id/edit',
                builder: (context, state) {
                  final expenseId = state.pathParameters['id']!;
                  return Consumer(
                    builder: (context, ref, _) {
                      final expenses = ref.watch(expensesStreamProvider).value ?? [];
                      final expense = expenses.where((e) => e.id == expenseId).firstOrNull;
                      if (expense == null) {
                        return const Scaffold(body: Center(child: Text('المصروف غير موجود')));
                      }
                      return EditExpenseScreen(expense: expense);
                    },
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
            routes: [
              GoRoute(
                path: 'revenue-detail',
                builder: (context, state) => const RevenueDetailScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddMaterialScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (context, state) {
                  final materialId = state.pathParameters['id']!;
                  return Consumer(
                    builder: (context, ref, _) {
                      final materials = ref.watch(materialsStreamProvider).value ?? [];
                      final material = materials.where((m) => m.id == materialId).firstOrNull;
                      if (material == null) {
                        return const Scaffold(body: Center(child: Text('الخامة غير موجودة')));
                      }
                      return AddMaterialScreen(material: material);
                    },
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/workers',
            builder: (context, state) => const WorkersScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddWorkerScreen(),
              ),
              GoRoute(
                path: ':id/edit',
                builder: (context, state) {
                  final workerId = state.pathParameters['id']!;
                  return Consumer(
                    builder: (context, ref, _) {
                      final workers = ref.watch(workersStreamProvider).value ?? [];
                      final worker = workers.where((w) => w.id == workerId).firstOrNull;
                      if (worker == null) {
                        return const Scaffold(body: Center(child: Text('العامل غير موجود')));
                      }
                      return AddWorkerScreen(worker: worker);
                    },
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/workshop-debts',
            builder: (context, state) => const WorkshopDebtsScreen(),
          ),
        ],
      ),
    ],
  );
}
