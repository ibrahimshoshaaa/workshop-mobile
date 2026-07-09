import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme/app_theme.dart';

/// رسم دائري (Pie Chart) لتوزيع إجمالي قيمة الطلبات حسب نوع الصنف
class ItemTypePieChart extends StatelessWidget {
  final Map<String, double> data;
  const ItemTypePieChart({super.key, required this.data});

  static const _colors = [
    AppColors.wood,
    AppColors.amber,
    AppColors.navy,
    AppColors.success,
    AppColors.danger,
    AppColors.warning,
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('لا توجد بيانات كافية بعد', style: TextStyle(color: Colors.grey))),
      );
    }
    final total = data.values.fold<double>(0, (a, b) => a + b);
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        SizedBox(
          height: 140,
          width: 140,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: entries.asMap().entries.map((e) {
                final index = e.key;
                final entry = e.value;
                final percentage = total == 0 ? 0.0 : (entry.value / total * 100);
                return PieChartSectionData(
                  value: entry.value,
                  color: _colors[index % _colors.length],
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: 40,
                  titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.asMap().entries.map((e) {
              final index = e.key;
              final entry = e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: _colors[index % _colors.length], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
