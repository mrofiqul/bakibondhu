import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:bakibondhu/sync/sync_api.dart';
import 'package:bakibondhu/sync/sync_types.dart';

/// [SyncApi] over HTTPS against the backend's `/api/v1/sync` endpoints
/// (REST API spec §12). Written to the contract; exercised once the backend
/// exists. Auth: a JWT bearer token; tenant via the JWT / X-Business-Id.
class HttpSyncApi implements SyncApi {
  final http.Client _client;
  final Uri baseUrl; // e.g. https://api.bakibondhu.com
  final String Function() accessToken;

  HttpSyncApi({
    required this.baseUrl,
    required this.accessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer ${accessToken()}',
      };

  static String _kindCode(EntityKind k) => switch (k) {
        EntityKind.customer => 'customer',
        EntityKind.transaction => 'transaction',
        EntityKind.sale => 'sale',
        EntityKind.collection => 'collection',
        EntityKind.promise => 'promise',
      };

  static EntityKind _kindFrom(String s) => switch (s) {
        'customer' => EntityKind.customer,
        'sale' => EntityKind.sale,
        'collection' => EntityKind.collection,
        'promise' => EntityKind.promise,
        _ => EntityKind.transaction,
      };

  static String _pullKey(EntityKind k) => switch (k) {
        EntityKind.customer => 'customers',
        EntityKind.transaction => 'transactions',
        EntityKind.sale => 'sales',
        EntityKind.collection => 'collections',
        EntityKind.promise => 'promises',
      };

  static SyncState _stateFrom(String s) => switch (s.toUpperCase()) {
        'SYNCED' => SyncState.synced,
        'CONFLICT' => SyncState.conflict,
        _ => SyncState.failed,
      };

  @override
  Future<List<PushResultItem>> push({
    required String deviceId,
    required List<LocalChange> changes,
  }) async {
    final body = jsonEncode({
      'device_id': deviceId,
      'changes': [
        for (final c in changes)
          {
            'entity': _kindCode(c.kind),
            'local_id': c.localId,
            'op': c.op,
            'data': c.data,
          }
      ],
    });
    final res = await _client.post(
      baseUrl.resolve('/api/v1/sync/push'),
      headers: _headers,
      body: body,
    );
    _ensureOk(res);
    final decoded = jsonDecode(res.body) as Map<String, Object?>;
    final results = (decoded['results'] as List).cast<Map<String, Object?>>();
    return [
      for (final r in results)
        PushResultItem(
          kind: _kindFrom(r['entity'] as String),
          localId: r['local_id'] as String,
          serverId: r['server_id'] as String?,
          status: _stateFrom(r['sync_status'] as String),
          reason: r['reason'] as String?,
        )
    ];
  }

  @override
  Future<PullData> pull({required String? since, required String deviceId}) async {
    final uri = baseUrl.resolve('/api/v1/sync/pull').replace(queryParameters: {
      if (since != null) 'since': since,
      'device_id': deviceId,
    });
    final res = await _client.get(uri, headers: _headers);
    _ensureOk(res);
    final decoded = jsonDecode(res.body) as Map<String, Object?>;

    final records = <ServerRecord>[];
    for (final kind in EntityKind.values) {
      final key = _pullKey(kind);
      for (final row in (decoded[key] as List? ?? const [])
          .cast<Map<String, Object?>>()) {
        records.add(ServerRecord(
          kind: kind,
          id: row['id'] as String,
          data: row,
          updatedAt: DateTime.parse(row['updated_at'] as String),
        ));
      }
    }
    return PullData(
      records: records,
      serverTime: decoded['server_time'] as String,
      hasMore: (decoded['has_more'] as bool?) ?? false,
      expiresAt: decoded['expires_at'] as String?,
    );
  }

  void _ensureOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException(
          'sync failed: HTTP ${res.statusCode} ${res.body}');
    }
  }
}
