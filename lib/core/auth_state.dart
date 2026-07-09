import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_credentials.dart';
import '../services/firebase_service.dart';

const _loggedInKey = 'is_logged_in';
const _usernameKey = 'logged_in_username';

/// حالة تسجيل الدخول - بس true/false، متخزّنة محليًا على الجهاز (SharedPreferences).
/// استخدمنا ValueNotifier عادي (مش Riverpod provider) عشان يتوصل مباشرة
/// بـ GoRouter (refreshListenable) من غير أي طبقة وسيطة تعقّد الموضوع.
class AuthState {
  AuthState._();

  static final ValueNotifier<bool> isLoggedIn = ValueNotifier(false);

  /// اسم اليوزر الحالي اللي داخل بيه (مفيد لصفحة الإعدادات)
  static String? currentUsername;

  /// يتنادى مرة واحدة في main() قبل تشغيل التطبيق، عشان لو المستخدم
  /// كان مسجّل دخول قبل كده يفضل داخل من غير ما يدخل تاني كل مرة يفتح التطبيق
  static Future<void> loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn.value = prefs.getBool(_loggedInKey) ?? false;
    currentUsername = prefs.getString(_usernameKey);
  }

  static Future<bool> login(String username, String password) async {
    final trimmedUser = username.trim();

    // الحساب الرئيسي الثابت في الكود - خط أمان دائم، يفضل شغال حتى لو
    // حصلت أي مشكلة في حسابات app_users على Realtime Database
    final isMasterValid =
        trimmedUser == AppCredentials.username && password == AppCredentials.password;

    // الحسابات الإضافية (العمال) المخزّنة في app_users وبتتزامن بين الأجهزة.
    // بنحاول نتحقق منها بس لو مفيش نت أو حصل خطأ، منسيبش المستخدم عالق -
    // الحساب الرئيسي فوق بيفضل شغال في كل الأحوال
    bool isExtraValid = false;
    if (!isMasterValid) {
      try {
        isExtraValid = await FirebaseService.instance.verifyExtraUser(trimmedUser, password);
      } catch (_) {
        isExtraValid = false;
      }
    }

    final isValid = isMasterValid || isExtraValid;

    if (isValid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loggedInKey, true);
      await prefs.setString(_usernameKey, trimmedUser);
      currentUsername = trimmedUser;
      isLoggedIn.value = true;
    }
    return isValid;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, false);
    await prefs.remove(_usernameKey);
    currentUsername = null;
    isLoggedIn.value = false;
  }
}
