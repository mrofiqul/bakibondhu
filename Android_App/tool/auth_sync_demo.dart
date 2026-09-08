// Live auth + sync demo — the app's REAL AuthApi + SyncEngine + HttpSyncApi
// against the running (JWT-protected, Postgres-backed) backend.
//
//   1) backend up:  cd Backend/BakiBondhu.Api && dotnet run
//   2) run:         dart run tool/auth_sync_demo.dart [http://host:5080]
import 'package:uuid/uuid.dart';

import 'package:bakibondhu/data/auth_api.dart';
import 'package:bakibondhu/sync/http_sync_api.dart';
import 'package:bakibondhu/sync/sync_engine.dart';
import 'package:bakibondhu/sync/sync_store.dart';
import 'package:bakibondhu/sync/sync_types.dart';

Future<void> main(List<String> args) async {
  final base = Uri.parse(args.isNotEmpty ? args.first : 'http://localhost:5080');
  const uuid = Uuid();

  // 1) register (creates owner + business) -> JWT
  final auth = AuthApi(baseUrl: base);
  final phone = '019${DateTime.now().millisecondsSinceEpoch % 100000000}';
  final reg = await auth.register(
      name: 'Rafiq', phone: phone, password: 'secret123', businessName: 'Rafiq Traders');
  print('register: role=${reg.role}  token=${reg.accessToken.substring(0, 16)}…');

  // 2) sync with the token (app's real HttpSyncApi + engine)
  final api = HttpSyncApi(baseUrl: base, accessToken: () => reg.accessToken);
  final c1 = uuid.v4(), t1 = uuid.v4();
  final store = InMemorySyncStore([
    LocalChange(kind: EntityKind.customer, localId: c1,
        data: const {'name': 'করিম স্টোর', 'phone': '01712345678'}),
    LocalChange(kind: EntityKind.transaction, localId: t1,
        data: {'customer_local_id': c1, 'type': 'credit', 'amount_paisa': 2000000}),
  ]);
  final engine = SyncEngine(api: api, store: store, deviceId: uuid.v4());

  final report = await engine.syncNow();
  print('syncNow: $report');
  print('pulled ${store.applied.length} record(s) back:');
  for (final r in store.applied) {
    print('  [${r.kind.name}] ${r.id}  ${r.data['name'] ?? r.data['type']}');
  }
}
