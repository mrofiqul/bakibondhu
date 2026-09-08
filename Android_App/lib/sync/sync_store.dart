import 'package:bakibondhu/sync/sync_types.dart';

/// The engine's view of the local store: what still needs pushing, how to record
/// the server's verdict, how to apply pulled records, and the pull cursor.
///
/// The on-device implementation is backed by SQLite (a follow-up: add a
/// `server_id` column + a cursor row); [InMemorySyncStore] backs the tests.
abstract class SyncStore {
  Future<List<LocalChange>> pendingChanges();
  Future<void> markSynced(EntityKind kind, String localId, String serverId);
  Future<void> markFailed(EntityKind kind, String localId, String reason);
  Future<void> markConflict(EntityKind kind, String localId, String reason);
  Future<void> applyServerRecords(List<ServerRecord> records);
  Future<String?> cursor();
  Future<void> setCursor(String value);

  /// Counts by sync state, for the Sync Center.
  Future<SyncStatusCounts> status();

  /// Records currently in CONFLICT, for the review screen.
  Future<List<LocalChange>> conflicts();
}

/// In-memory [SyncStore] for tests.
class InMemorySyncStore implements SyncStore {
  final List<LocalChange> _pending;
  final Map<String, SyncState> statuses = {};
  final Map<String, String> serverIds = {};
  final List<ServerRecord> applied = [];
  String? _cursor;

  InMemorySyncStore(List<LocalChange> pending) : _pending = List.of(pending) {
    for (final c in _pending) {
      statuses[_key(c.kind, c.localId)] = SyncState.pending;
    }
  }

  String _key(EntityKind kind, String localId) => '$kind|$localId';

  @override
  Future<List<LocalChange>> pendingChanges() async => _pending
      .where((c) => statuses[_key(c.kind, c.localId)] != SyncState.synced)
      .toList();

  @override
  Future<void> markSynced(EntityKind kind, String localId, String serverId) async {
    statuses[_key(kind, localId)] = SyncState.synced;
    serverIds[_key(kind, localId)] = serverId;
  }

  @override
  Future<void> markFailed(EntityKind kind, String localId, String reason) async {
    statuses[_key(kind, localId)] = SyncState.failed;
  }

  @override
  Future<void> markConflict(EntityKind kind, String localId, String reason) async {
    statuses[_key(kind, localId)] = SyncState.conflict;
  }

  @override
  Future<void> applyServerRecords(List<ServerRecord> records) async =>
      applied.addAll(records);

  @override
  Future<String?> cursor() async => _cursor;

  @override
  Future<void> setCursor(String value) async => _cursor = value;

  @override
  Future<SyncStatusCounts> status() async {
    var pending = 0, failed = 0, conflict = 0, synced = 0;
    for (final s in statuses.values) {
      switch (s) {
        case SyncState.local:
        case SyncState.pending:
          pending++;
        case SyncState.failed:
          failed++;
        case SyncState.conflict:
          conflict++;
        case SyncState.synced:
          synced++;
      }
    }
    return SyncStatusCounts(
        pending: pending, failed: failed, conflict: conflict, synced: synced);
  }

  @override
  Future<List<LocalChange>> conflicts() async => _pending
      .where((c) => statuses[_key(c.kind, c.localId)] == SyncState.conflict)
      .toList();
}
