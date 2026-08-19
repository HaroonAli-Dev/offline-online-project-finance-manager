enum SyncStatus {
  pending('pending'),
  synced('synced'),
  pendingDelete('pending_delete'),
  conflict('conflict');

  const SyncStatus(this.databaseValue);

  final String databaseValue;
}
