import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// مكتبة عناصر UI مشتركة بنفس روح تصميم الداشبورد (كروت ناعمة بدون ظل،
/// حواف مدورة كبيرة، أيقونات جوه مربعات ملونة بشفافية) - عشان باقي
/// الصفحات تبقى متسقة بصريًا مع الداشبورد بدل ما تفضل بتصميم قديم مختلف

/// مربع أيقونة ملون بديل عن CircleAvatar - نفس أسلوب أيقونات الداشبورد
class ModernIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final String? letter;
  const ModernIconBadge({super.key, required this.icon, required this.color, this.size = 44, this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(size * 0.32)),
      alignment: Alignment.center,
      child: letter != null
          ? Text(letter!, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: size * 0.4))
          : Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// كارت عنصر عام بديل عن Card+ListTile - نفس حواف وأسلوب كروت الداشبورد
class ModernListCard extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  const ModernListCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      child: title,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      DefaultTextStyle.merge(
                        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// حقل بحث بنفس ناعمية عناصر الداشبورد - خلفية مليانة بدون حد ظاهر
class ModernSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  const ModernSearchField({super.key, required this.hint, required this.onChanged, this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.wood, width: 1.5),
        ),
      ),
    );
  }
}

/// شريحة فلتر بنفس تدرّج ألوان الداشبورد
class ModernChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ModernChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.wood : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.wood : Theme.of(context).dividerColor.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}

/// بانر إجمالي (مديونيات، مصروفات...) بنفس أسلوب HeroCashCard في الداشبورد
class ModernSummaryBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final Widget value;
  const ModernSummaryBanner({super.key, required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.14) : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: color)),
                const SizedBox(height: 6),
                DefaultTextStyle.merge(
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                  child: value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// حالة فارغة موحّدة - أيقونة كبيرة باهتة + نص، بدل النص الرمادي المجرد
class ModernEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const ModernEmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}
