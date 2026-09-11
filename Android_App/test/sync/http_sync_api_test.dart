import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bakibondhu/sync/http_sync_api.dart';
import 'package:bakibondhu/sync/sync_types.dart';

/// Pins the exact HTTP wire format that the PHP backend (`php_backend/`)
/// implements. The Dart client and the PHP server share nothing but this JSON
/// shape, so if either side drifts, this test should catch it.
void main() {
  final base = Uri.parse('https://bakibondhu.infinityfreeapp.com');

  test('push sends the contract body and parses the verdicts', () async {
    late Map<String, Object?> sent;
    final client = MockClient((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/sync/push');
      expect(req.headers['authorization'], 'Bearer tok-123');
      sent = jsonDecode(req.body) as Map<String, Object?>;
      // The server answers with a per-item verdict.
      return http.Response(
        jsonEncode({
          'results': [
            {
              'entity': 'customer',
              'local_id': 'loc-c1',
              'server_id': 'loc-c1',
              'sync_status': 'SYNCED',
              'reason': null,
            },
            {
              'entity': 'transaction',
              'local_id': 'loc-t1',
              'server_id': null,
              'sync_status': 'FAILED',
              'reason': 'unknown customer',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = HttpSyncApi(
      baseUrl: base,
      accessToken: () => 'tok-123',
      client: client,
    );

    final results = await api.push(deviceId: 'device-1', changes: [
      const LocalChange(
        kind: EntityKind.customer,
        localId: 'loc-c1',
        data: {'name': 'করিম', 'phone': null},
      ),
      const LocalChange(
        kind: EntityKind.transaction,
        localId: 'loc-t1',
        data: {
          'customer_local_id': 'loc-c1',
          'type': 'credit',
          'amount_paisa': 12000,
        },
      ),
    ]);

    // Request shape the PHP `handle_sync_push` reads.
    expect(sent['device_id'], 'device-1');
    final changes = (sent['changes'] as List).cast<Map<String, Object?>>();
    expect(changes[0]['entity'], 'customer');
    expect(changes[0]['local_id'], 'loc-c1');
    expect(changes[0]['op'], 'create');
    expect((changes[0]['data'] as Map)['name'], 'করিম');
    expect(changes[1]['entity'], 'transaction');
    expect((changes[1]['data'] as Map)['amount_paisa'], 12000);

    // Response parsing.
    expect(results[0].kind, EntityKind.customer);
    expect(results[0].status, SyncState.synced);
    expect(results[0].serverId, 'loc-c1');
    expect(results[1].status, SyncState.failed);
    expect(results[1].reason, 'unknown customer');
  });

  test('pull sends since/device_id and parses customers + transactions', () async {
    late Uri calledUri;
    final client = MockClient((req) async {
      expect(req.method, 'GET');
      calledUri = req.url;
      expect(req.headers['authorization'], 'Bearer tok-123');
      return http.Response(
        jsonEncode({
          'customers': [
            {
              'id': 'srv-c1',
              'name': 'রহিম',
              'phone': '01700000000',
              'updated_at': '2026-09-11T06:30:00.123456Z',
            },
          ],
          'transactions': [
            {
              'id': 'srv-t1',
              'customer_id': 'srv-c1',
              'type': 'credit',
              'amount_paisa': 5000,
              'due_date': null,
              'note': null,
              'updated_at': '2026-09-11T06:31:00.000000Z',
            },
          ],
          'server_time': '2026-09-11 06:31:05.000000',
          'has_more': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = HttpSyncApi(
      baseUrl: base,
      accessToken: () => 'tok-123',
      client: client,
    );

    final data = await api.pull(since: '2026-09-10 00:00:00.000000', deviceId: 'device-1');

    expect(calledUri.path, '/api/v1/sync/pull');
    expect(calledUri.queryParameters['since'], '2026-09-10 00:00:00.000000');
    expect(calledUri.queryParameters['device_id'], 'device-1');

    expect(data.records.length, 2);
    final customer = data.records.firstWhere((r) => r.kind == EntityKind.customer);
    expect(customer.id, 'srv-c1');
    expect(customer.data['name'], 'রহিম');
    final txn = data.records.firstWhere((r) => r.kind == EntityKind.transaction);
    expect(txn.data['customer_id'], 'srv-c1');
    expect(txn.data['amount_paisa'], 5000);
    // server_time is the opaque cursor passed back as the next `since`.
    expect(data.serverTime, '2026-09-11 06:31:05.000000');
    expect(data.hasMore, false);
  });
}
