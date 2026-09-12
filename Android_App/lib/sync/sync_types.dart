// Types shared by the sync engine (Offline Sync Technical Design §2–§6).

/// Lifecycle of a locally-created record (spec §17).
enum SyncState { local, pending, synced, failed, conflict }

/// Which entity a change refers to.
enum EntityKind { customer, transaction, sale }

/// A locally-created change to push to the server. Carries a stable [localId]
/// so the server can dedupe on (business_id, device_id, local_id).
class LocalChange {
  final EntityKind kind;
  final String localId;
  final String op; // 'create' (append-only; v1 has no update/delete)
  final Map<String, Object?> data;

  const LocalChange({
    required this.kind,
    required this.localId,
    required this.data,
    this.op = 'create',
  });
}

/// The server's per-item verdict for a pushed change.
class PushResultItem {
  final EntityKind kind;
  final String localId;
  final String? serverId; // present when synced
  final SyncState status; // synced | conflict | failed
  final String? reason;

  const PushResultItem({
    required this.kind,
    required this.localId,
    required this.status,
    this.serverId,
    this.reason,
  });
}

/// A record returned by the server on pull, to upsert into the local store.
class ServerRecord {
  final EntityKind kind;
  final String id; // server id
  final Map<String, Object?> data;
  final DateTime updatedAt;

  const ServerRecord({
    required this.kind,
    required this.id,
    required this.data,
    required this.updatedAt,
  });
}

/// The result of a pull: records changed since the cursor, plus the new cursor.
class PullData {
  final List<ServerRecord> records;
  final String serverTime; // opaque cursor to pass as the next `since`
  final bool hasMore;

  const PullData({
    required this.records,
    required this.serverTime,
    this.hasMore = false,
  });
}

/// A snapshot of the local outbox by state, for the Sync Center (spec §5.14).
class SyncStatusCounts {
  final int pending;
  final int failed;
  final int conflict;
  final int synced;

  const SyncStatusCounts({
    this.pending = 0,
    this.failed = 0,
    this.conflict = 0,
    this.synced = 0,
  });

  int get unsynced => pending + failed + conflict;
  int get total => unsynced + synced;
}

/// Outcome of a sync run, for the UI / logs.
class SyncReport {
  final int pushed;
  final int failed;
  final int conflicts;
  final int pulled;

  const SyncReport({
    this.pushed = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.pulled = 0,
  });

  @override
  String toString() =>
      'SyncReport(pushed=$pushed, failed=$failed, conflicts=$conflicts, pulled=$pulled)';
}
