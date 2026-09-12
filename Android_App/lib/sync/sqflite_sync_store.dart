import 'package:sqflite/sqflite.dart';

import 'package:bakibondhu/sync/sync_store.dart';
import 'package:bakibondhu/sync/sync_types.dart';

/// [SyncStore] backed by the local SQLite database. Reads the outbox
/// (`sync_status <> 'SYNCED'`), records the server's verdict on each record,
/// upserts pulled records (deduped by `server_id`), and keeps the pull cursor
/// in `sync_meta`. Mirrors the tested in-memory store's behaviour.
class SqfliteSyncStore implements SyncStore {
  static const _cursorKey = 'pull_cursor';

  final Database _db;
  SqfliteSyncStore(this._db);

  static String _table(EntityKind kind) => switch (kind) {
        EntityKind.customer => 'customers',
        EntityKind.transaction => 'transactions',
        EntityKind.sale => 'sales',
      };

  // ---- outbox ---------------------------------------------------------------

  @override
  Future<List<LocalChange>> pendingChanges() async {
    final changes = <LocalChange>[];

    // Customers first so a transaction's customer resolves on the server.
    final custRows = await _db.query('customers',
        columns: ['id', 'name', 'phone'],
        where: "sync_status <> 'SYNCED'",
        orderBy: 'created_at');
    for (final r in custRows) {
      changes.add(LocalChange(
        kind: EntityKind.customer,
        localId: r['id'] as String,
        data: {'name': r['name'], 'phone': r['phone']},
      ));
    }

    final txnRows = await _db.query('transactions',
        columns: [
          'id',
          'customer_id',
          'type',
          'amount_paisa',
          'due_date',
          'note',
          'created_at'
        ],
        where: "sync_status <> 'SYNCED'",
        orderBy: 'created_at');
    for (final r in txnRows) {
      changes.add(LocalChange(
        kind: EntityKind.transaction,
        localId: r['id'] as String,
        data: {
          'customer_local_id': r['customer_id'],
          'type': r['type'],
          'amount_paisa': r['amount_paisa'],
          'due_date': r['due_date'],
          'note': r['note'],
          'created_at': r['created_at'],
        },
      ));
    }

    // Sales (no customer dependency).
    final saleRows = await _db.query('sales',
        columns: ['id', 'amount_paisa', 'note', 'sold_at'],
        where: "sync_status <> 'SYNCED'",
        orderBy: 'sold_at');
    for (final r in saleRows) {
      changes.add(LocalChange(
        kind: EntityKind.sale,
        localId: r['id'] as String,
        data: {
          'amount_paisa': r['amount_paisa'],
          'note': r['note'],
          'sold_at': r['sold_at'],
        },
      ));
    }
    return changes;
  }

  @override
  Future<void> markSynced(EntityKind kind, String localId, String serverId) async {
    await _db.update(
      _table(kind),
      {'server_id': serverId, 'sync_status': 'SYNCED'},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  @override
  Future<void> markFailed(EntityKind kind, String localId, String reason) =>
      _setStatus(kind, localId, 'FAILED');

  @override
  Future<void> markConflict(EntityKind kind, String localId, String reason) =>
      _setStatus(kind, localId, 'CONFLICT');

  Future<void> _setStatus(EntityKind kind, String localId, String status) async {
    await _db.update(_table(kind), {'sync_status': status},
        where: 'id = ?', whereArgs: [localId]);
  }

  // ---- pull -----------------------------------------------------------------

  @override
  Future<void> applyServerRecords(List<ServerRecord> records) async {
    // Apply customers before transactions to satisfy the FK.
    final ordered = [...records]..sort((a, b) => a.kind.index.compareTo(b.kind.index));
    await _db.transaction((txn) async {
      for (final r in ordered) {
        switch (r.kind) {
          case EntityKind.customer:
            await _upsertCustomer(txn, r);
          case EntityKind.transaction:
            await _upsertTransaction(txn, r);
          case EntityKind.sale:
            await _upsertSale(txn, r);
        }
      }
    });
  }

  Future<void> _upsertSale(DatabaseExecutor txn, ServerRecord r) async {
    final values = {
      'amount_paisa': _amountPaisa(r.data),
      'note': r.data['note'],
      'sold_at': (r.data['sold_at'] as String?) ??
          r.updatedAt.toUtc().toIso8601String(),
      'sync_status': 'SYNCED',
    };
    final updated = await txn.update('sales', values,
        where: 'server_id = ?', whereArgs: [r.id]);
    if (updated == 0) {
      await txn.insert('sales', {
        'id': r.id,
        'server_id': r.id,
        ...values,
      });
    }
  }

  Future<void> _upsertCustomer(DatabaseExecutor txn, ServerRecord r) async {
    final values = {
      'name': r.data['name'],
      'phone': r.data['phone'],
      'sync_status': 'SYNCED',
    };
    final updated = await txn.update('customers', values,
        where: 'server_id = ?', whereArgs: [r.id]);
    if (updated == 0) {
      await txn.insert('customers', {
        'id': r.id, // pulled records key on the server id locally
        'server_id': r.id,
        'created_at': r.updatedAt.toUtc().toIso8601String(),
        ...values,
      });
    }
  }

  Future<void> _upsertTransaction(DatabaseExecutor txn, ServerRecord r) async {
    final values = {
      'customer_id': r.data['customer_id'],
      'type': r.data['type'],
      'amount_paisa': _amountPaisa(r.data),
      'due_date': r.data['due_date'],
      'note': r.data['note'],
      'sync_status': 'SYNCED',
    };
    final updated = await txn.update('transactions', values,
        where: 'server_id = ?', whereArgs: [r.id]);
    if (updated == 0) {
      await txn.insert('transactions', {
        'id': r.id,
        'server_id': r.id,
        'created_at': r.updatedAt.toUtc().toIso8601String(),
        ...values,
      });
    }
  }

  /// The server sends money as a fixed-decimal; store integer paisa. Accepts
  /// either `amount_paisa` or a decimal `amount` (finalized with the backend).
  static int _amountPaisa(Map<String, Object?> data) {
    final paisa = data['amount_paisa'];
    if (paisa is int) return paisa;
    final amount = data['amount'];
    if (amount is num) return (amount * 100).round();
    return 0;
  }

  // ---- cursor ---------------------------------------------------------------

  @override
  Future<String?> cursor() async {
    final rows = await _db.query('sync_meta',
        columns: ['value'], where: 'key = ?', whereArgs: [_cursorKey], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> setCursor(String value) async {
    await _db.insert(
      'sync_meta',
      {'key': _cursorKey, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---- status / conflicts ---------------------------------------------------

  @override
  Future<SyncStatusCounts> status() async {
    final rows = await _db.rawQuery('''
      SELECT sync_status AS s, COUNT(*) AS c FROM (
        SELECT sync_status FROM customers
        UNION ALL
        SELECT sync_status FROM transactions
        UNION ALL
        SELECT sync_status FROM sales
      ) GROUP BY sync_status
    ''');
    var pending = 0, failed = 0, conflict = 0, synced = 0;
    for (final r in rows) {
      final c = (r['c'] as int?) ?? 0;
      switch ((r['s'] as String?) ?? '') {
        case 'SYNCED':
          synced += c;
        case 'FAILED':
          failed += c;
        case 'CONFLICT':
          conflict += c;
        default: // LOCAL / PENDING
          pending += c;
      }
    }
    return SyncStatusCounts(
        pending: pending, failed: failed, conflict: conflict, synced: synced);
  }

  @override
  Future<List<LocalChange>> conflicts() async {
    final out = <LocalChange>[];
    for (final kind in EntityKind.values) {
      final rows = await _db.query(_table(kind),
          columns: ['id'], where: "sync_status = 'CONFLICT'");
      for (final r in rows) {
        out.add(LocalChange(
            kind: kind, localId: r['id'] as String, data: const {}));
      }
    }
    return out;
  }
}
