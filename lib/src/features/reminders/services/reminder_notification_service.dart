import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderNotificationService {
  ReminderNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

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
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
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
      await _plugin.cancel(id: notificationId(reminderId));
      await _plugin.zonedSchedule(
        id: notificationId(reminderId),
        title: title,
        body: 'Reminder due now',
        scheduledDate: tz.TZDateTime.from(dueAt.toLocal(), tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'finance_reminders',
            'Finance reminders',
            channelDescription: 'Due reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
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
      await _plugin.cancel(id: notificationId(reminderId));
    } catch (_) {
      // Notification delivery is optional and must not block local CRUD.
    }
  }
}
