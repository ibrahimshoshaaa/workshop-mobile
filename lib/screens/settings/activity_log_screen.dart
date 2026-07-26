import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/activity_provider.dart';
import '../../widgets/modern_ui.dart';

/// شاشة سجل الأنشطة - بتجمع كل حاجة حصلت في التطبيق (طلبات، دفعات،
/// مصروفات، عملاء، مرتبات، تحويلات، ديون ورشة) من مصدر واحد مشترك على
/// فايربيز، يعني بتظهر هنا سواء اتعملت من الموبايل أو من الديسكتوب
class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  ActivityKind? _filter;

  static const _filterLabels = {
    ActivityKind.newOrder: 'طلبات',
    ActivityKind.orderPayment: 'دفعات عملاء',
    ActivityKind.customerRefund: 'مرتجعات عملاء',
    ActivityKind.expense: 'مصروفات',
    ActivityKind.newCustomer: 'عملاء',
    ActivityKind.workerPayment: 'مرتبات',
    ActivityKind.cashTransfer: 'تحويلات',
    ActivityKind.workshopDebt: 'ديون الورشة',
  };

  /// عنوان تجميع اليوم - "النهاردة" / "إمبارح" / التاريخ الكامل
  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'النهاردة';
    if (day == today.subtract(const Duration(days: 1))) return 'إمبارح';
    return DateFormat('EEEE، d MMMM yyyy', 'ar').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(activityLogProvider);
    final items = _filter == null ? all : all.where((a) => a.kind == _filter).toList();

    // تجميع العناصر تحت عنوان كل يوم بالترتيب
    final grouped = <String, List<ActivityItem>>{};
    for (final item in items) {
      final label = _dayLabel(item.time);
      grouped.putIfAbsent(label, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الأنشطة')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                ModernChip(label: 'الكل', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                const SizedBox(width: 8),
                ..._filterLabels.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ModernChip(
                        label: e.value,
                        selected: _filter == e.key,
                        onTap: () => setState(() => _filter = e.key),
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const ModernEmptyState(icon: Icons.history_rounded, message: 'لسه مفيش أي نشاط مسجّل')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: grouped.entries.expand((group) {
                      return [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            group.key,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                        ...group.value.map((item) => ModernListCard(
                              leading: ModernIconBadge(icon: item.icon, color: item.color),
                              title: Text(item.title),
                              subtitle: Text(item.subtitle),
                              trailing: Text(
                                DateFormat('h:mm a', 'ar').format(item.time),
                                style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                              ),
                            )),
                      ];
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
