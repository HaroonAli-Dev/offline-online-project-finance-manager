import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderNotificationService {
  ReminderNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _windowsAppUserModelId =
      'FinanceConstructionManager.ReminderNotifications.1';
  static const _windowsNotificationGuid =
      '8f4c1d8e-4d47-4e2e-b0f8-6f9c7b8d3a21';

  static int notificationId(String reminderId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in reminderId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    tz.initializeTimeZones();
    final initialized = await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        windows: WindowsInitializationSettings(
          appName: 'Finance & Construction Manager',
          appUserModelId: _windowsAppUserModelId,
          guid: _windowsNotificationGuid,
        ),
      ),
    );
    _initialized = initialized ?? false;
  }

  Future<void> schedule({
    required String reminderId,
    required String title,
    required DateTime dueAt,
  }) async {
    if (kIsWeb || dueAt.isBefore(DateTime.now())) return;
    try {
      await initialize();
      if (!_initialized) return;
      await _plugin.cancel(notificationId(reminderId));
      await _plugin.zonedSchedule(
        notificationId(reminderId),
        title,
        'Reminder due now',
        tz.TZDateTime.from(dueAt.toLocal(), tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'finance_reminders',
            'Finance reminders',
            channelDescription: 'Due reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          windows: WindowsNotificationDetails(
            duration: WindowsNotificationDuration.long,
            timestamp: null,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // Notification delivery is optional and must not block local CRUD.
    }
  }

  Future<void> cancel(String reminderId) async {
    if (kIsWeb) return;
    try {
      await initialize();
      if (!_initialized) return;
      await _plugin.cancel(notificationId(reminderId));
    } catch (_) {
      // Notification delivery is optional and must not block local CRUD.
    }
  }
}
