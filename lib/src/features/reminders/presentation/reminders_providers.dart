import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/database_provider.dart';
import '../data/reminders_repository.dart';
import '../domain/reminder_model.dart';

final remindersRepositoryProvider = Provider<RemindersRepository>((ref) {
  return RemindersRepository(ref.watch(appDatabaseProvider), const Uuid());
});

final remindersSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final remindersPriorityFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// null = all, true = done, false = pending
final remindersDoneFilterProvider = StateProvider.autoDispose<bool?>(
  (ref) => null,
);

final remindersSchemeFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final remindersProvider = StreamProvider.autoDispose<List<ReminderModel>>((
  ref,
) {
  final search = ref.watch(remindersSearchProvider);
  final priority = ref.watch(remindersPriorityFilterProvider);
  final done = ref.watch(remindersDoneFilterProvider);
  final scheme = ref.watch(remindersSchemeFilterProvider);

  return ref
      .watch(remindersRepositoryProvider)
      .watchReminders(
        searchQuery: search,
        priorityFilter: priority,
        doneFilter: done,
        schemeFilter: scheme,
      );
});

/// Pending reminders that are overdue or due within the next 7 days.
/// Used by the Dashboard. Returns at most 5 items ordered by dueAt ASC.
final dashboardUpcomingRemindersProvider = StreamProvider<List<ReminderModel>>((
  ref,
) {
  return ref
      .watch(remindersRepositoryProvider)
      .watchReminders(doneFilter: false)
      .map((all) {
        final cutoff = DateTime.now().toUtc().add(const Duration(days: 7));
        return all
            .where((r) => r.dueAt == null || r.dueAt!.isBefore(cutoff))
            .take(5)
            .toList();
      });
});
