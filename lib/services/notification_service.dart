import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// خدمة الإشعارات المحلية - تنبيهات التسليمات القريبة والمديونيات.
/// كل الإشعارات دي محلية بالكامل (مش عن طريق سيرفر)، فبتشتغل حتى لو
/// مفيش نت خالص، بناءً على البيانات المتزامنة أصلاً على الجهاز
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _deliveryChannelId = 'delivery_reminders';
  static const _debtsChannelId = 'debts_reminders';
  static const _debtNotificationId = 999999; // ID ثابت لإشعار المديونيات (واحد بس دايمًا)

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    const deliveryChannel = AndroidNotificationChannel(
      _deliveryChannelId,
      'تنبيهات التسليم',
      description: 'تنبيهات قبل موعد تسليم الطلبات',
      importance: Importance.high,
    );
    const debtsChannel = AndroidNotificationChannel(
      _debtsChannelId,
      'تنبيهات المديونيات',
      description: 'تذكير دوري بالمديونيات المستحقة',
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(deliveryChannel);
    await androidPlugin?.createNotificationChannel(debtsChannel);

    _initialized = true;
  }

  /// يطلب إذن إظهار الإشعارات (لازم على أندرويد 13+) - يُستدعى مرة في main()
  Future<void> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('تعذّر طلب إذن الإشعارات: $e');
    }
  }

  int _reminderIdFor(String orderId, int offset) => (orderId.hashCode & 0x7FFFFFFF) + offset;

  /// جدولة تنبيهين لطلب معين: قبل التسليم بيوم، وفي يوم التسليم نفسه
  Future<void> scheduleOrderDeliveryReminders({
    required String orderId,
    required String customerName,
    required String itemType,
    required DateTime deliveryDate,
  }) async {
    await cancelOrderReminders(orderId);

    final dayBefore = tz.TZDateTime.from(
      DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day - 1, 9, 0),
      tz.local,
    );
    final onDay = tz.TZDateTime.from(
      DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day, 9, 0),
      tz.local,
    );
    final now = tz.TZDateTime.now(tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(_deliveryChannelId, 'تنبيهات التسليم', importance: Importance.high),
    );

    if (dayBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        _reminderIdFor(orderId, 1),
        'تسليم غدًا',
        '$customerName - $itemType مطلوب تسليمه غدًا',
        dayBefore,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    if (onDay.isAfter(now)) {
      await _plugin.zonedSchedule(
        _reminderIdFor(orderId, 2),
        'موعد التسليم اليوم',
        '$customerName - $itemType مطلوب تسليمه اليوم',
        onDay,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelOrderReminders(String orderId) async {
    await _plugin.cancel(_reminderIdFor(orderId, 1));
    await _plugin.cancel(_reminderIdFor(orderId, 2));
  }

  /// تذكير بالمديونيات - بيتجدول تاني كل مرة الداشبورد يتفتح بناءً على آخر
  /// رصيد، لبكرة الساعة 10 الصبح. لو اتفتح التطبيق قبل كده، بيتلغي القديم
  /// ويتجدول تاني برصيد محدّث - فعليًا بيشتغل كـ "تذكير لو مافتحتش التطبيق فترة"
  Future<void> scheduleDebtReminder(double totalDebts, int debtorsCount) async {
    await _plugin.cancel(_debtNotificationId);
    if (totalDebts <= 0) return;

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final scheduledTime = tz.TZDateTime.from(
      DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0),
      tz.local,
    );

    const details = NotificationDetails(
      android: AndroidNotificationDetails(_debtsChannelId, 'تنبيهات المديونيات'),
    );

    await _plugin.zonedSchedule(
      _debtNotificationId,
      'عندك مديونيات مستحقة',
      'إجمالي ${totalDebts.toStringAsFixed(0)} ج.م من $debtorsCount عميل - راجع صفحة المديونيات',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
