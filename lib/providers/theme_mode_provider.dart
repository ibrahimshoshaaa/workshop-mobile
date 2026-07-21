import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'app_theme_mode';

/// وضع الثيم (فاتح/غامق/حسب النظام) - متخزّن محليًا (SharedPreferences)
/// فبيفضل زي ما اختاره المستخدم حتى لو قفل التطبيق وفتحه تاني، وميتأثرش
/// بتغيير إعدادات النظام العامة زي وضع الخصوصية بالظبط
class AppThemeModeNotifier extends StateNotifier<ThemeMode> {
  AppThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeModeKey);
    state = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  /// بيلف بين الوضع الفاتح والغامق بس (من غير "حسب النظام") - مناسب لزرار
  /// سويتش سريع؛ لو المستخدم عايز "حسب النظام" يقدر يختارها من الإعدادات
  Future<void> toggleLightDark() async {
    final isCurrentlyDark = state == ThemeMode.dark;
    await setMode(isCurrentlyDark ? ThemeMode.light : ThemeMode.dark);
  }
}

final appThemeModeProvider = StateNotifierProvider<AppThemeModeNotifier, ThemeMode>(
  (ref) => AppThemeModeNotifier(),
);
