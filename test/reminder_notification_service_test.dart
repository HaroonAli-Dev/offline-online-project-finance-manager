import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/features/reminders/services/reminder_notification_service.dart';

void main() {
  test('notification ID is deterministic for a reminder ID', () {
    final first = ReminderNotificationService.notificationId('reminder-123');
    final second = ReminderNotificationService.notificationId('reminder-123');

    expect(first, second);
    expect(first, greaterThanOrEqualTo(0));
  });

  test('different reminder IDs receive separate notification IDs', () {
    expect(
      ReminderNotificationService.notificationId('reminder-123'),
      isNot(ReminderNotificationService.notificationId('reminder-456')),
    );
  });
}
