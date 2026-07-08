# ورشة التنجيد والأثاث (Workshop Manager)

تطبيق Flutter لإدارة ورشة تنجيد وأثاث: العملاء، الطلبات، العربون والمديونيات،
مصروفات الورشة، وأجور/سحبيات الصنايعية — بواجهة عربية كاملة RTL.

## الستاك التقني

| الطبقة | التقنية |
|---|---|
| الواجهة | Flutter 3.44.2 + Riverpod (State Management) |
| التنقل | go_router (مع ShellRoute لشريط تنقل سفلي ثابت) |
| قاعدة البيانات | Firebase **Realtime Database** (مش Firestore) |
| الصور | Firebase Storage |
| تسجيل الدخول | يوزر وباسورد محليين بسيطين (بدون Firebase Auth) |
| أوفلاين | Hive CE (كاش محلي يعرض فورًا وقت فتح التطبيق) |
| الخط | Cairo (عبر google_fonts) |

اخترنا Realtime Database بدل Firestore عشان قواعد الأمان بتتظبط مباشرة من
صفحة الـ Firebase Console (زرار Publish بس)، من غير أي حاجة تتنشر بالـ CLI
أو Node.js. ده اللي كان بيسبب مشاكل "permission-denied" قبل كده.

## هيكل المشروع

```
lib/
  core/
    theme/app_theme.dart        # الألوان والثيم (فاتح/غامق)
    router/app_router.dart      # كل مسارات التطبيق + حماية تسجيل الدخول
    constants/app_constants.dart# أنواع الأصناف، الحالات، الفئات
    constants/app_credentials.dart # ⚠️ اليوزر والباسورد بتاعة الدخول - غيّرهم هنا
    auth_state.dart              # حالة تسجيل الدخول المحلية (ValueNotifier بسيط)
  models/                       # CustomerModel, OrderModel, TransactionModel, ExpenseModel
  services/
    firebase_service.dart       # كل التعامل مع Realtime Database/Storage من مكان واحد
    pdf_export_service.dart     # توليد فواتير وتقارير PDF
    excel_export_service.dart   # توليد تقرير Excel
  local/
    local_cache_service.dart    # طبقة Hive CE (Cache-then-Network)
  providers/
    app_providers.dart          # كل الـ Riverpod providers (streams, فلاتر, إحصائيات)
  screens/
    auth/          # تسجيل الدخول
    dashboard/      # الرئيسية - إحصائيات + تسليمات قريبة
    customers/     # قائمة العملاء، إضافة، ملف العميل
    orders/        # قائمة الطلبات، إضافة (برفع صور)، تفاصيل + سجل دفعات
    debts/         # صفحة المديونيات مرتبة تلقائيًا
    expenses/      # المصروفات + أجور الصنايعية
    reports/       # تصدير PDF/Excel
    root_shell.dart# شريط التنقل السفلي
android-config/
  app_build.gradle.kts  # نسخة معدّة مسبقًا من ملف بناء أندرويد، بتتحط مكان
                          # النسخة الافتراضية أوتوماتيك في كل تشغيلة CI
firebase/
  google-services.json  # (لازم ترفعه إنت - راجع خطوات التشغيل تحت)
database.rules.json     # قواعد الأمان (تتنسخ يدويًا في Firebase Console)
```

## قاعدة البيانات (Realtime Database)

شكل البيانات تحت الجذر مباشرة (كل قسم عبارة عن Node منفصل):

```
customers/
  {pushId}: { name, phone, address, createdAt }
orders/
  {pushId}: { customerId, customerName, itemType, details, images, status,
              totalAmount, totalPaid, deliveryDate, createdAt }
transactions/
  {pushId}: { orderId, customerId, amountPaid, paymentDate, paymentType }
expenses/
  {pushId}: { amount, category, description, workerName?, date }
```

- كل التواريخ متخزنة كـ milliseconds (رقم عادي) مش أي نوع خاص، عشان تبقى
  بسيطة تتقرأ من أي مكان (حتى من الـ Python POS أو أي أداة تانية لو حبيت تربطهم لاحقًا).
- `remainingAmount` (المديونية المتبقية) **محسوبة دايمًا** في التطبيق
  (totalAmount - totalPaid) مش حقل مخزّن، عشان تفضل متطابقة دايمًا.
- كل دفعة جديدة بتتحدّث totalPaid في الطلب عن طريق `runTransaction` (نفس
  فكرة الـ atomic update اللي شغال بيها الـ Python POS)، عشان لو جهازين
  بيدفعوا في نفس اللحظة الأرقام تفضل صح.

## تسجيل الدخول

مفيش Firebase Auth ولا حسابات على السيرفر خالص. اليوزر والباسورد متعرّفين
مباشرة في الكود، في الملف:

```
lib/core/constants/app_credentials.dart
```

القيم الافتراضية دلوقتي:
- يوزر: `admin`
- باسورد: `workshop2026`

**غيّرهم** لأي حاجة إنت عايزها (افتح الملف في GitHub، عدّل، Commit). كل
اللي بيدخل بنفس اليوزر والباسورد ده بيشوف نفس البيانات، مفيش أدوار أو
صلاحيات متفرقة دلوقتي (كل حد داخل = كل الصلاحيات).

⚠️ ملحوظة أمان: الطريقة دي بسيطة ومناسبة لورشة صغيرة، مش حماية قوية زي
حساب حقيقي، لأن أي حد يشوف كود التطبيق (لو الريبو عام public مثلاً) يقدر
يشوف القيم دي. لو الريبو خاص (private) فده كافي جدًا.

## خطوات التشغيل (بالمتصفح بس - بدون أي أوامر Terminal)

### الخطوة 1: فعّل Realtime Database من Firebase Console

1. روح [console.firebase.google.com](https://console.firebase.google.com) →
   افتح مشروعك (workshopmanage-e7555 أو اسم مشروعك).
2. من القائمة الجانبية، دوس **Realtime Database** → **Create Database**.
3. اختار أي منطقة (Location) قريبة، وابدأ في **وضع الاختبار (test mode)**
   أو أي وضع - هنستبدل القواعد يدويًا بعد شوية على أي حال.
4. بعد ما تتعمل، هتلاقي **رابط قاعدة البيانات** ظاهر فوق الصفحة، شكله يكون
   حاجة زي:
   ```
   https://workshopmanage-e7555-default-rtdb.firebaseio.com
   ```
   أو لو منطقة تانية:
   ```
   https://workshopmanage-e7555-default-rtdb.europe-west1.firebasedatabase.app
   ```
   **انسخ الرابط ده**، هنحتاجه في الخطوة 3.

5. روح تبويب **Rules** (جنب تبويب Data)، وامسح اللي موجود، والصق بدله:
   ```json
   {
     "rules": {
       ".read": true,
       ".write": true
     }
   }
   ```
   ودوس **Publish**. (نفس المحتوى موجود في ملف `database.rules.json` بالريبو لو حبيت ترجعله).

6. لسه محتاج تفعّل **Storage** كمان (لصور الطلبات): من القائمة الجانبية
   → Storage → Get started.

### الخطوة 2: ارفع ملف google-services.json (لو لسه معملتوش)

لو عندك الملف ده من قبل كده، سيبه زي ما هو مش محتاج تعمل حاجة. لو لسه،
نزّله من Project Settings ⚙️ > تطبيقاتك، وارفعه في مجلد `firebase/` بالريبو.

### الخطوة 3: حط رابط قاعدة البيانات في الكود

افتح `lib/firebase_options.dart` في GitHub (✏️ عدّل)، ولاقي السطر ده جوه
قسم `android`:
```dart
databaseURL: 'REPLACE_WITH_YOUR_DATABASE_URL',
```
واستبدله بالرابط اللي نسخته في الخطوة 1، يبقى شكله كده:
```dart
databaseURL: 'https://workshopmanage-e7555-default-rtdb.firebaseio.com',
```
اعمل Commit.

### الخطوة 4: (اختياري) غيّر اليوزر والباسورد

افتح `lib/core/constants/app_credentials.dart` وغيّر القيم لأي حاجة إنت
عايزها. اعمل Commit.

### الخطوة 5: خلي GitHub Actions يشتغل وانزّل الـ APK

أي `push` أو commit جديد على `main` هيشغّل الـ workflow تلقائيًا. تابعه من
تبويب **Actions**. لما يخلص بعلامة ✅ خضرا، انزل تحت لحد قسم **Artifacts**،
هتلاقي `workshop-manager-apk` — نزّله، فكّه، وجوه هتلاقي `app-release.apk`.
ابعته لموبايلك وثبّته (لازم تسمح بـ "تثبيت من مصادر غير معروفة" أول مرة).

## آخر التحسينات المنفذة

- **التحول من Firestore لـ Realtime Database:** عشان قواعد الأمان تتظبط
  من المتصفح مباشرة (Publish بضغطة زرار) من غير أي CLI أو نشر معقد، وده
  كان سبب أخطاء "permission-denied" اللي قابلتك.
- **تسجيل دخول محلي بسيط:** يوزر وباسورد إنت اللي بتحددهم في الكود، بدل
  حسابات Firebase Auth اللي كانت محتاجة تتضاف يدويًا من الـ Console.
- **إزالة نظام الأدوار (owner/worker) والإشعارات والـ Cloud Functions:**
  عشان تقليل عدد الحاجات اللي ممكن تتعطل أو تحتاج إعداد إضافي. ممكن نرجعهم
  تاني في أي وقت لو حبيت بعد ما الأساسيات تشتغل تمام.

## نقاط ممكن تضيفها لاحقًا (مش أساسية دلوقتي)

1. إشعارات push لمواعيد التسليم القريبة (كانت موجودة وشيلناها للتبسيط).
2. أدوار مستخدمين متعددة (owner/worker) لو الورشة كبرت واحتجت صلاحيات متفرقة.
3. حماية أقوى لقاعدة البيانات (بدل `.read/.write: true` المفتوحة دلوقتي).
