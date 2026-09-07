import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The on-device SQLite store (offline-first). Mirrors the synced entities from
/// the server schema, kept deliberately small for v1's core loop.
///
/// Notes:
///  - Money is stored as INTEGER `amount_paisa` (1 taka = 100 paisa) — never a
///    float, matching the server's NUMERIC(14,2).
///  - Transactions are append-only; a mistake is corrected with a reversing row
///    (`reversal_of_id`), never an edit/delete.
///  - `sync_status` tracks the offline outbox (LOCAL/PENDING/SYNCED/…) for the
///    sync engine added later.
///  - Balances/aging are COMPUTED from these rows in Dart (domain layer), never
///    stored.
const int kLocalDbVersion = 1;

const List<String> kLocalSchema = [
  '''
  CREATE TABLE IF NOT EXISTS customers (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    phone        TEXT,
    created_at   TEXT NOT NULL,
    sync_status  TEXT NOT NULL DEFAULT 'PENDING'
  );
  ''',
  '''
  CREATE TABLE IF NOT EXISTS transactions (
    id              TEXT PRIMARY KEY,
    customer_id     TEXT NOT NULL,
    type            TEXT NOT NULL,               -- credit|payment|adjustment_debit|adjustment_credit
    amount_paisa    INTEGER NOT NULL CHECK (amount_paisa >= 0),
    due_date        TEXT,
    note            TEXT,
    reversal_of_id  TEXT,
    created_at      TEXT NOT NULL,
    sync_status     TEXT NOT NULL DEFAULT 'PENDING',
    FOREIGN KEY (customer_id) REFERENCES customers (id)
  );
  ''',
  'CREATE INDEX IF NOT EXISTS idx_txn_customer ON transactions (customer_id);',
  'CREATE INDEX IF NOT EXISTS idx_txn_sync ON transactions (sync_status);',
];

/// Opens (and creates on first run) the local database.
Future<Database> openLocalDatabase({String fileName = 'bakibondhu.db'}) async {
  final dir = await getDatabasesPath();
  return openDatabase(
    p.join(dir, fileName),
    version: kLocalDbVersion,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON;'),
    onCreate: (db, version) async {
      for (final stmt in kLocalSchema) {
        await db.execute(stmt);
      }
    },
  );
}
