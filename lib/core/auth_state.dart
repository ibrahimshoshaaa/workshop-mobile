import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_email_mapper.dart';
import '../services/firebase_service.dart';

const _usernameKey = 'logged_in_username';
const _isAdminKey = 'logged_in_is_admin';
const _permsJsonKey = 'logged_in_permissions_json';

/// حالة تسجيل الدخول - بقت مبنية على Firebase Authentication الحقيقي
/// (مش مقارنة يوزر/باسورد يدوية جوّه التطبيق زي الأول). كل يوزرنيم
/// (زي "admin" أو "ibrahim") بيتحوّل لإيميل مصطنع (auth_email_mapper.dart)
/// عشان Firebase Auth بيتطلب صيغة إيميل.
///
/// التفرقة بين الأدمن والعمال بقت كالتالي: لو اليوزرنيم موجود كسجل في
/// app_users (يعني عامل إضافي اتضاف من صفحة الإعدادات) → مش أدمن، وبياخد
/// صلاحياته من السجل ده. لو مش موجود في app_users خالص لكن نجح تسجيل
/// الدخول (يعني الحساب متعمول يدويًا في Firebase Console) → بيتحسب أدمن
/// (الحساب الرئيسي).
///
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

  /// يتنادى مرة واحدة في main() قبل تشغيل التطبيق. Firebase Auth بيحتفظ
  /// بجلسة الدخول محليًا على الجهاز لوحده (حتى من غير نت)، فبنسأله هو الأول
  /// "هل فيه يوزر مسجّل دخول فعليًا؟" بدل ما نعتمد بس على قيمة محفوظة إحنا
  /// خزّناها يدويًا زي الأول (اللي كانت ممكن تفضل true حتى لو الجلسة نفسها
  /// بقت غير صالحة).
  static Future<void> loadSavedState() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      isLoggedIn.value = false;
      currentUsername = null;
      isAdmin = false;
      _permissions = {};
      return;
    }

    // فيه جلسة Firebase صالحة - نرجّع اسم اليوزر والصلاحيات من الكاش المحلي
    // (سريع ومتاح حتى من غير نت)، وبعدين نحاول نحدّثهم في الخلفية لو فيه نت
    final prefs = await SharedPreferences.getInstance();
    currentUsername = prefs.getString(_usernameKey);
    isAdmin = prefs.getBool(_isAdminKey) ?? false;
    final permsRaw = prefs.getString(_permsJsonKey);
    if (permsRaw != null && permsRaw.isNotEmpty) {
      final decoded = jsonDecode(permsRaw) as Map;
      _permissions = decoded.map((k, v) => MapEntry(k.toString(), v == true));
    }
    isLoggedIn.value = true;
  }

  static Future<bool> login(String username, String password) async {
    final trimmedUser = username.trim();
    final email = usernameToAuthEmail(trimmedUser);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (_) {
      // يوزر/باسورد غلط، أو الحساب مش موجود، أو مفيش نت - في كل الحالات
      // دي تسجيل الدخول بيفشل بوضوح بدل ما نسيب أي مسار بديل يعدّي
      return false;
    } catch (_) {
      return false;
    }

    // نجح تسجيل الدخول في Firebase - دلوقتي نحدد هل ده عامل إضافي (له سجل
    // في app_users) ولا الحساب الرئيسي (مفيش سجل ليه)
    Map<String, bool> permissions = {};
    bool admin = true;
    try {
      final users = await FirebaseService.instance.streamUsers().first;
      final match = users.where((u) => u.username == trimmedUser).firstOrNull;
      if (match != null) {
        admin = false;
        permissions = match.permissions;
      }
    } catch (_) {
      // مفيش نت نقدر نتأكد بيه - نديله صلاحيات أدمن مؤقتًا عشان منقفلش
      // عليه برّه التطبيق، وهيتظبط لوحده أول ما refreshCurrentUserPermissions
      // تنجح تتصل بالنت
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, trimmedUser);
    await prefs.setBool(_isAdminKey, admin);
    await prefs.setString(_permsJsonKey, jsonEncode(permissions));

    currentUsername = trimmedUser;
    isAdmin = admin;
    _permissions = permissions;
    isLoggedIn.value = true;
    permissionsVersion.value++;
    return true;
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
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_isAdminKey);
    await prefs.remove(_permsJsonKey);
    currentUsername = null;
    isAdmin = false;
    _permissions = {};
    isLoggedIn.value = false;
  }
}
