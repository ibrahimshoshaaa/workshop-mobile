import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_credentials.dart';
import '../services/firebase_service.dart';

const _loggedInKey = 'is_logged_in';
const _usernameKey = 'logged_in_username';
const _isAdminKey = 'logged_in_is_admin';
const _permsJsonKey = 'logged_in_permissions_json';

/// حالة تسجيل الدخول - بس true/false، متخزّنة محليًا على الجهاز (SharedPreferences).
/// استخدمنا ValueNotifier عادي (مش Riverpod provider) عشان يتوصل مباشرة
/// بـ GoRouter (refreshListenable) من غير أي طبقة وسيطة تعقّد الموضوع.
class AuthState {
  AuthState._();

  static final ValueNotifier<bool> isLoggedIn = ValueNotifier(false);

  /// بيتزوّد كل ما الصلاحيات تتغيّر - أي ويدجت عايز يعيد بناء نفسه لما
  /// الصلاحيات تتحدّث (زي شريط التنقل السفلي) يسمعله بـ ValueListenableBuilder
  static final ValueNotifier<int> permissionsVersion = ValueNotifier(0);

  /// اسم اليوزر الحالي اللي داخل بيه (مفيد لصفحة الإعدادات)
  static String? currentUsername;

  /// الأدمن (الحساب الرئيسي) عنده كل الصلاحيات دايمًا. الحسابات الإضافية
  /// (العمال) بتتحدد حسب _permissions
  static bool isAdmin = false;
  static Map<String, bool> _permissions = {};

  /// بيتحقق هل اليوزر الحالي مسموحله يشوف القسم ده - نفس منطق تطبيق
  /// الديسكتوب بالظبط (أي قسم مش محدد صراحةً بيتحسب مسموح افتراضيًا)
  static bool can(String screenKey) => isAdmin || (_permissions[screenKey] ?? true);

  /// يتنادى مرة واحدة في main() قبل تشغيل التطبيق، عشان لو المستخدم
  /// كان مسجّل دخول قبل كده يفضل داخل من غير ما يدخل تاني كل مرة يفتح التطبيق
  static Future<void> loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn.value = prefs.getBool(_loggedInKey) ?? false;
    currentUsername = prefs.getString(_usernameKey);
    isAdmin = prefs.getBool(_isAdminKey) ?? false;
    final permsRaw = prefs.getString(_permsJsonKey);
    if (permsRaw != null && permsRaw.isNotEmpty) {
      final decoded = jsonDecode(permsRaw) as Map;
      _permissions = decoded.map((k, v) => MapEntry(k.toString(), v == true));
    }
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
    Map<String, bool> extraPermissions = {};
    bool isExtraValid = false;
    if (!isMasterValid) {
      try {
        final extraUser = await FirebaseService.instance.verifyExtraUser(trimmedUser, password);
        if (extraUser != null) {
          isExtraValid = true;
          extraPermissions = extraUser.permissions;
        }
      } catch (_) {
        isExtraValid = false;
      }
    }

    final isValid = isMasterValid || isExtraValid;

    if (isValid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_loggedInKey, true);
      await prefs.setString(_usernameKey, trimmedUser);
      await prefs.setBool(_isAdminKey, isMasterValid);
      await prefs.setString(_permsJsonKey, jsonEncode(extraPermissions));
      currentUsername = trimmedUser;
      isAdmin = isMasterValid;
      _permissions = extraPermissions;
      isLoggedIn.value = true;
      permissionsVersion.value++;
    }
    return isValid;
  }

  /// بيحدّث صلاحيات اليوزر الحالي من Firebase - بيتنادى بعد كل مزامنة
  /// ناجحة، عشان لو الأدمن غيّر صلاحيات حد وهو شغال، التغيير يوصله من
  /// غير ما يضطر يسجّل خروج ويدخل تاني
  static Future<void> refreshCurrentUserPermissions() async {
    if (isAdmin || currentUsername == null) return;
    try {
      final users = await FirebaseService.instance.streamUsers().first;
      final match = users.where((u) => u.username == currentUsername).firstOrNull;
      if (match != null) {
        _permissions = match.permissions;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_permsJsonKey, jsonEncode(_permissions));
        permissionsVersion.value++;
      }
    } catch (_) {
      // مفيش نت - نسيب الصلاحيات المحفوظة محليًا زي ما هي
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, false);
    await prefs.remove(_usernameKey);
    await prefs.remove(_isAdminKey);
    await prefs.remove(_permsJsonKey);
    currentUsername = null;
    isAdmin = false;
    _permissions = {};
    isLoggedIn.value = false;
  }
}
