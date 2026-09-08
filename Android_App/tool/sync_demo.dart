// Live sync round-trip demo — runs the APP'S REAL sync code (HttpSyncApi +
// SyncEngine) against a running backend, no emulator needed.
//
//   1) start the backend:  cd Backend/BakiBondhu.Api && dotnet run
//   2) run this:           flutter pub get && dart run tool/sync_demo.dart
//
// Override the URL with:   dart run tool/sync_demo.dart http://host:5080
import 'package:bakibondhu/sync/http_sync_api.dart';
import 'package:bakibondhu/sync/sync_engine.dart';
import 'package:bakibondhu/sync/sync_store.dart';
import 'package:bakibondhu/sync/sync_types.dart';

Future<void> main(List<String> args) async {
  final base = args.isNotEmpty ? args.first : 'http://localhost:5080';
  final api = HttpSyncApi(baseUrl: Uri.parse(base), accessToken: () => 'dev');

  // Two locally-created records, as the app would produce them.
  final store = InMemorySyncStore([
    const LocalChange(
        kind: EntityKind.customer,
        localId: 'lc1',
        data: {'name': 'করিম স্টোর', 'phone': '01712345678'}),
    const LocalChange(
        kind: EntityKind.transaction,
        localId: 'lt1',
        data: {'customer_local_id': 'lc1', 'type': 'credit', 'amount_paisa': 2000000}),
  ]);
  final engine = SyncEngine(api: api, store: store, deviceId: 'demo-device');

  print('backend: $base');
  final before = await store.status();
  print('before  → pending=${before.pending} synced=${before.synced}');

  final report = await engine.syncNow();
  print('syncNow → $report');

  final after = await store.status();
  print('after   → pending=${after.pending} synced=${after.synced}');
  store.serverIds.forEach((k, v) => print('  mapped $k  ->  $v'));
  print('pulled  → ${store.applied.length} record(s) from server');
  for (final r in store.applied) {
    print('  [${r.kind.name}] ${r.id}  ${r.data['name'] ?? r.data['type']}');
  }
}
