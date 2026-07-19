import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/auth_state.dart';
import 'firebase_options.dart';
import 'local/local_cache_service.dart';
import 'services/notification_service.dart';
import 'services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // بعض الأحيان أندرويد بيعمل تهيئة تلقائية لـ Firebase App الافتراضي
    // ("[DEFAULT]") من قبل ما كود Dart يشتغل أصلاً (بسبب google-services.json
    // + بلجن Google Services)، فلو حصل كده مش لازم نعتبره خطأ
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }

    // تفعيل التخزين المحلي لـ Realtime Database - أي كتابة (إضافة/تعديل/حذف)
    // بتتحفظ على الجهاز فورًا وتتزامن تلقائيًا لحظة رجوع النت
    try {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
    } catch (_) {}

    await initializeDateFormatting('ar'); // تهيئة تنسيق التواريخ بالعربي
    await Hive.initFlutter(); // تهيئة Hive CE للتخزين المحلي (offline-first)
    await LocalCacheService.instance.init();
    await AuthState.loadSavedState(); // استرجاع حالة تسجيل الدخول المحفوظة على الجهاز

    // إصلاح لمرة واحدة بس - راجع التعليق على الدالة نفسها
    unawaited(FirebaseService.instance.repairMissingOverpaymentDebtsOnce());

    // تهيئة الإشعارات المحلية وطلب إذن إظهارها (مطلوب إجباريًا أندرويد 13+)
    await NotificationService.instance.init();
    await NotificationService.instance.requestPermission();
  } catch (e, stackTrace) {
    debugPrint('❌ خطأ أثناء تهيئة التطبيق: $e');
    debugPrint('$stackTrace');
    runApp(_StartupErrorApp(error: e.toString()));
    return;
  }

  runApp(const ProviderScope(child: WorkshopApp()));
}

/// شاشة بديلة تظهر بس لو حصل خطأ أثناء تهيئة Firebase/Hive قبل ما التطبيق
/// الأساسي يقدر يبدأ، عشان تعرف السبب بدل شاشة سودا من غير أي توضيح
class _StartupErrorApp extends StatelessWidget {
  final String error;
  const _StartupErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Scaffold(
        backgroundColor: const Color(0xFFFAF6F0),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 56, color: Color(0xFFB3261E)),
                  const SizedBox(height: 16),
                  const Text(
                    'حصل خطأ أثناء تشغيل التطبيق',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'الاحتمال الأكبر: بيانات Firebase في firebase_options.dart لسه فيها '
                    'قيم وهمية (REPLACE_WITH_YOUR_...) ولسه متبدلتش بالقيم الحقيقية، '
                    'أو databaseURL بتاعة Realtime Database لسه مضافاش.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                    child: SelectableText(
                      error,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkshopApp extends StatelessWidget {
  const WorkshopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tahoun Royal Home',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: buildAppRouter(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
    );
  }
}
