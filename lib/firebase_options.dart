// ملف إعدادات Firebase - القيم دي مأخوذة من google-services.json
// بتاع مشروع workshopmanage-e7555
//
// ✅ databaseURL اتحطت بالفعل تحت (Realtime Database اتعملت)

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'الويب مش مدعوم في النسخة دي من التطبيق.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions غير مُعرّفة لهذه المنصة.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA2u7EIySiILna5ycloOpHav3BP93lrOSA',
    appId: '1:678686082224:android:63b36d2f891fa43773e775',
    messagingSenderId: '678686082224',
    projectId: 'workshopmanage-e7555',
    storageBucket: 'workshopmanage-e7555.firebasestorage.app',
    databaseURL: 'https://workshopmanage-e7555-default-rtdb.firebaseio.com',
  );

  // ⚠️ لسه محتاجة تتظبط لو حبيت تبني نسخة iOS لاحقًا (مش مستخدمة دلوقتي
  // لأن التطبيق بيتبني Android بس عن طريق GitHub Actions الحالي)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_YOUR_API_KEY',
    appId: 'REPLACE_WITH_YOUR_APP_ID',
    messagingSenderId: 'REPLACE_WITH_YOUR_SENDER_ID',
    projectId: 'REPLACE_WITH_YOUR_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.workshopManager',
    databaseURL: 'REPLACE_WITH_YOUR_DATABASE_URL',
  );
}
