import 'dart:convert';
import 'package:hive_ce/hive.dart';

/// طبقة تخزين محلي عامة (Offline Cache) فوق Hive CE.
/// تُستخدم كـ "Write-Through Cache": كل مرة يوصل تحديث من Realtime Database،
/// بيتخزن نسخة محلية منه في نفس اللحظة. لو التطبيق فتح من غير نت
/// (أو قبل ما الاتصال يتأسس)، بنقرأ من هنا فورًا كنقطة بداية بدل ما الشاشة تفضل فاضية.
class LocalCacheService {
  LocalCacheService._();
  static final LocalCacheService instance = LocalCacheService._();

  static const String customersBox = 'cache_customers';
  static const String ordersBox = 'cache_orders';
  static const String expensesBox = 'cache_expenses';

  /// افتح كل الصناديق المطلوبة - يُستدعى مرة واحدة في main() قبل runApp
  Future<void> init() async {
    await Future.wait([
      Hive.openBox<String>(customersBox),
      Hive.openBox<String>(ordersBox),
      Hive.openBox<String>(expensesBox),
    ]);
  }

  Box<String> _box(String name) => Hive.box<String>(name);

  /// تخزين قائمة كاملة من العناصر (تستبدل كل المحتوى القديم بالكامل
  /// بأحدث نسخة جاية من قاعدة البيانات، عشان لا يتراكم عناصر محذوفة)
  Future<void> replaceAll(String boxName, Map<String, Map<String, dynamic>> idToMap) async {
    final box = _box(boxName);
    await box.clear();
    final encoded = idToMap.map((id, map) => MapEntry(id, jsonEncode(map)));
    await box.putAll(encoded);
  }

  /// قراءة كل العناصر المخزّنة محليًا كـ Map<id, data>
  Map<String, Map<String, dynamic>> readAll(String boxName) {
    final box = _box(boxName);
    final result = <String, Map<String, dynamic>>{};
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        result[key.toString()] = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {
        // تجاهل أي سجل تالف بدل ما يوقف التطبيق كله
      }
    }
    return result;
  }

  Future<void> clearAll() async {
    await Future.wait([
      _box(customersBox).clear(),
      _box(ordersBox).clear(),
      _box(expensesBox).clear(),
    ]);
  }
}
