import 'package:bakibondhu/sync/sync_types.dart';

/// The transport the sync engine talks to: push local changes, pull server
/// changes. Implemented over HTTP (`http_sync_api.dart`) and as an in-memory
/// fake (`in_memory_sync_api.dart`) for tests.
abstract class SyncApi {
  /// Uploads locally-created changes. The server is idempotent on
  /// (business_id, device_id, local_id) and returns a per-item verdict.
  Future<List<PushResultItem>> push({
    required String deviceId,
    required List<LocalChange> changes,
  });

  /// Returns everything changed after [since] (null = first sync).
  Future<PullData> pull({
    required String? since,
    required String deviceId,
  });
}
