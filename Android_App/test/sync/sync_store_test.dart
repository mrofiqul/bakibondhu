import 'package:flutter_test/flutter_test.dart';

import 'package:bakibondhu/sync/sync_store.dart';
import 'package:bakibondhu/sync/sync_types.dart';

void main() {
  test('status() counts by state; conflicts() lists conflicted records', () async {
    final store = InMemorySyncStore([
      const LocalChange(kind: EntityKind.customer, localId: 'c1', data: {}),
      const LocalChange(kind: EntityKind.transaction, localId: 't1', data: {}),
      const LocalChange(kind: EntityKind.transaction, localId: 't2', data: {}),
    ]);

    var s = await store.status();
    expect(s.pending, 3);
    expect(s.synced, 0);
    expect(s.unsynced, 3);

    await store.markSynced(EntityKind.customer, 'c1', 'srv-c1');
    await store.markConflict(EntityKind.transaction, 't2', 'duplicate');

    s = await store.status();
    expect(s.synced, 1);
    expect(s.pending, 1);
    expect(s.conflict, 1);
    expect(s.unsynced, 2);

    final conflicts = await store.conflicts();
    expect(conflicts.map((c) => c.localId).toList(), ['t2']);
  });
}
