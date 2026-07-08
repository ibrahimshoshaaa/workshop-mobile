import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_credentials.dart';

const _loggedInKey = 'is_logged_in';

/// حالة تسجيل الدخول - بس true/false، متخزّنة محليًا على الجهاز (SharedPreferences).
/// استخدمنا ValueNotifier عادي (مش Riverpod provider) عشان يتوصل مباشرة
/// بـ GoRouter (refreshListenable) من غير أي طبقة وسيطة تعقّد الموضوع.
class AuthState {
  AuthState._();

  static final ValueNotifier<bool> isLoggedIn = ValueNotifier(false);

  /// يتنادى مرة واحدة في main() قبل تشغيل التطبيق، عشان لو المستخدم
  /// كان مسجّل دخول قبل كده يفضل داخل من غير ما يدخل تاني كل مرة يفتح التطبيق
  static Future<void> loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn.value = prefs.getBool(_loggedInKey) ?? false;
  }

  static Future<bool> login(String username, String password) async {
    final isValid = username.trim() == AppCredentials.username && password == AppCredentials.password;
    if (isValid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loggedInKey, true);
      isLoggedIn.value = true;
    }
    return isValid;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, false);
    isLoggedIn.value = false;
  }
}
