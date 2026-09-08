import 'package:flutter_test/flutter_test.dart';

import 'package:bakibondhu/sync/in_memory_sync_api.dart';
import 'package:bakibondhu/sync/sync_engine.dart';
import 'package:bakibondhu/sync/sync_store.dart';
import 'package:bakibondhu/sync/sync_types.dart';

void main() {
  LocalChange customer(String localId, String name) => LocalChange(
        kind: EntityKind.customer,
        localId: localId,
        data: {'name': name},
      );
  LocalChange txn(String localId, int amountPaisa) => LocalChange(
        kind: EntityKind.transaction,
        localId: localId,
        data: {'type': 'credit', 'amount_paisa': amountPaisa},
      );

  SyncEngine engine(SyncStore store, {InMemorySyncApi? api}) => SyncEngine(
        api: api ?? InMemorySyncApi(),
        store: store,
        deviceId: 'device-1',
      );

  test('push maps local ids to server ids and marks them synced', () async {
    final store = InMemorySyncStore([customer('loc-c1', 'করিম'), txn('loc-t1', 12000)]);
    final report = await engine(store).push();

    expect(report.pushed, 2);
    expect(report.conflicts, 0);
    expect(store.statuses['${EntityKind.customer}|loc-c1'], SyncState.synced);
    expect(store.serverIds['${EntityKind.transaction}|loc-t1'], isNotNull);
    // once synced, they are no longer pending
    expect(await store.pendingChanges(), isEmpty);
  });

  test('conflict is surfaced, never silently overwritten', () async {
    final store = InMemorySyncStore([txn('loc-bad', 12000)]);
    final api = InMemorySyncApi(conflictLocalIds: {'loc-bad'});
    final report = await engine(store, api: api).push();

    expect(report.conflicts, 1);
    expect(report.pushed, 0);
    expect(store.statuses['${EntityKind.transaction}|loc-bad'], SyncState.conflict);
  });

  test('retry is idempotent — same local id keeps the same server id', () async {
    final api = InMemorySyncApi();
    final store = InMemorySyncStore([txn('loc-t1', 5000)]);

    await engine(store, api: api).push();
    final firstServerId = store.serverIds['${EntityKind.transaction}|loc-t1'];

    // Simulate the app not recording success (status reset) and pushing again.
    store.statuses['${EntityKind.transaction}|loc-t1'] = SyncState.pending;
    await engine(store, api: api).push();
    final secondServerId = store.serverIds['${EntityKind.transaction}|loc-t1'];

    expect(secondServerId, firstServerId); // no duplicate created
  });

  test('pull applies server records and advances the cursor', () async {
    final store = InMemorySyncStore([]);
    final api = InMemorySyncApi(
      pullRecords: [
        ServerRecord(
          kind: EntityKind.customer,
          id: 'srv-c1',
          data: {'name': 'রহিম'},
          updatedAt: DateTime(2026, 9, 7),
        ),
      ],
      serverTime: 'T2',
    );

    final count = await engine(store, api: api).pull();
    expect(count, 1);
    expect(store.applied.single.id, 'srv-c1');
    expect(await store.cursor(), 'T2');
  });

  test('syncNow pushes then pulls', () async {
    final store = InMemorySyncStore([customer('loc-c1', 'করিম')]);
    final report = await engine(store).syncNow();
    expect(report.pushed, 1);
    expect(await store.cursor(), 'T1');
  });
}
