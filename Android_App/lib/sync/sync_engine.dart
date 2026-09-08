import 'package:bakibondhu/sync/sync_api.dart';
import 'package:bakibondhu/sync/sync_store.dart';
import 'package:bakibondhu/sync/sync_types.dart';

/// Orchestrates offline sync (Offline Sync Technical Design §4).
///
/// Push first, then pull (dependencies flow that way). Everything is idempotent,
/// so retrying after a failure or restart is always safe; financial conflicts
/// are surfaced for review, never silently overwritten (§37).
class SyncEngine {
  final SyncApi api;
  final SyncStore store;
  final String deviceId;

  SyncEngine({required this.api, required this.store, required this.deviceId});

  /// Uploads pending local changes and records each verdict.
  Future<SyncReport> push() async {
    final changes = await store.pendingChanges();
    if (changes.isEmpty) return const SyncReport();

    final results = await api.push(deviceId: deviceId, changes: changes);

    var synced = 0, failed = 0, conflicts = 0;
    for (final r in results) {
      switch (r.status) {
        case SyncState.synced:
          // A synced verdict must carry the server id.
          await store.markSynced(r.kind, r.localId, r.serverId!);
          synced++;
        case SyncState.conflict:
          await store.markConflict(r.kind, r.localId, r.reason ?? 'conflict');
          conflicts++;
        case SyncState.failed:
          await store.markFailed(r.kind, r.localId, r.reason ?? 'failed');
          failed++;
        case SyncState.local:
        case SyncState.pending:
          // Server should never return these; treat as failed to retry later.
          await store.markFailed(r.kind, r.localId, 'unexpected ${r.status}');
          failed++;
      }
    }
    return SyncReport(pushed: synced, failed: failed, conflicts: conflicts);
  }

  /// Downloads server changes since the stored cursor and advances it.
  Future<int> pull() async {
    final since = await store.cursor();
    final data = await api.pull(since: since, deviceId: deviceId);
    await store.applyServerRecords(data.records);
    await store.setCursor(data.serverTime);
    return data.records.length;
  }

  /// A full cycle: push, then pull.
  Future<SyncReport> syncNow() async {
    final pushed = await push();
    final pulled = await pull();
    return SyncReport(
      pushed: pushed.pushed,
      failed: pushed.failed,
      conflicts: pushed.conflicts,
      pulled: pulled,
    );
  }
}
