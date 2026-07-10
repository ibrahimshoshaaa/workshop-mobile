import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _deliveryChannelId = 'delivery_reminders';
  static const _debtsChannelId = 'debts_reminders';
  static const _inventoryChannelId = 'inventory_reminders';
  static const _debtNotificationId = 999999;
  static const _lowStockNotificationId = 999998;

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
    const inventoryChannel = AndroidNotificationChannel(
      _inventoryChannelId,
      'تنبيهات المخزون',
      description: 'تنبيه لما خامة توصل للحد الأدنى',
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(deliveryChannel);
    await androidPlugin?.createNotificationChannel(debtsChannel);
    await androidPlugin?.createNotificationChannel(inventoryChannel);

    _initialized = true;
  }

  Future<void> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('تعذّر طلب إذن الإشعارات: $e');
    }
  }

  int _reminderIdFor(String orderId, int offset) => (orderId.hashCode & 0x7FFFFFFF) + offset;

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

  /// تنبيه لبكرة الساعة 9:30 الصبح لو فيه خامات وصلت للحد الأدنى، بيتحدّث
  /// تلقائيًا كل مرة الداشبورد يتفتح بناءً على آخر حالة للمخزون
  Future<void> scheduleLowStockReminder(List<String> lowStockNames) async {
    await _plugin.cancel(_lowStockNotificationId);
    if (lowStockNames.isEmpty) return;

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final scheduledTime = tz.TZDateTime.from(
      DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 30),
      tz.local,
    );

    const details = NotificationDetails(
      android: AndroidNotificationDetails(_inventoryChannelId, 'تنبيهات المخزون'),
    );

    final namesText = lowStockNames.take(3).join('، ');
    final extra = lowStockNames.length > 3 ? ' و${lowStockNames.length - 3} غيرهم' : '';

    await _plugin.zonedSchedule(
      _lowStockNotificationId,
      'خامات على وشك النفاد',
      '$namesText$extra - راجع صفحة المخزون',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
