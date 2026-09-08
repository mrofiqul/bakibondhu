import 'package:bakibondhu/sync/sync_api.dart';
import 'package:bakibondhu/sync/sync_types.dart';

/// A fake server for tests and offline demos. It assigns server ids and is
/// **idempotent** on (deviceId, localId) — re-pushing the same change returns
/// the same server id, never a duplicate (spec §21/§27). It can be told to
/// force a conflict for specific local ids.
class InMemorySyncApi implements SyncApi {
  final Set<String> conflictLocalIds;
  final List<ServerRecord> pullRecords;
  final String serverTime;

  final Map<String, String> _assigned = {}; // deviceId|localId -> serverId
  int _seq = 0;

  InMemorySyncApi({
    this.conflictLocalIds = const {},
    List<ServerRecord>? pullRecords,
    this.serverTime = 'T1',
  }) : pullRecords = pullRecords ?? const [];

  @override
  Future<List<PushResultItem>> push({
    required String deviceId,
    required List<LocalChange> changes,
  }) async {
    final results = <PushResultItem>[];
    for (final c in changes) {
      if (conflictLocalIds.contains(c.localId)) {
        results.add(PushResultItem(
          kind: c.kind,
          localId: c.localId,
          status: SyncState.conflict,
          reason: 'duplicate_local_id_different_amount',
        ));
        continue;
      }
      final key = '$deviceId|${c.localId}';
      final serverId = _assigned.putIfAbsent(key, () => 'srv-${_seq++}');
      results.add(PushResultItem(
        kind: c.kind,
        localId: c.localId,
        status: SyncState.synced,
        serverId: serverId,
      ));
    }
    return results;
  }

  @override
  Future<PullData> pull({required String? since, required String deviceId}) async {
    return PullData(records: pullRecords, serverTime: serverTime);
  }
}
