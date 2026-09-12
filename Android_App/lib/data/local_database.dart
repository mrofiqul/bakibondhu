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
///  - `sync_status` tracks the offline outbox (LOCAL/PENDING/SYNCED/…) and
///    `server_id` is filled once the record is confirmed by the server
///    (see sqflite_sync_store.dart). `sync_meta` holds the pull cursor.
///  - Balances/aging are COMPUTED from these rows in Dart, never stored.
const int kLocalDbVersion = 5;

const List<String> kLocalSchema = [
  '''
  CREATE TABLE IF NOT EXISTS customers (
    id           TEXT PRIMARY KEY,
    server_id    TEXT,
    name         TEXT NOT NULL,
    phone        TEXT,
    address      TEXT,
    created_at   TEXT NOT NULL,
    sync_status  TEXT NOT NULL DEFAULT 'PENDING'
  );
  ''',
  '''
  CREATE TABLE IF NOT EXISTS transactions (
    id              TEXT PRIMARY KEY,
    server_id       TEXT,
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
  'CREATE INDEX IF NOT EXISTS idx_cust_server ON customers (server_id);',
  'CREATE INDEX IF NOT EXISTS idx_txn_server ON transactions (server_id);',
  'CREATE TABLE IF NOT EXISTS sync_meta (key TEXT PRIMARY KEY, value TEXT);',
  '''
  CREATE TABLE IF NOT EXISTS collection_activities (
    id             TEXT PRIMARY KEY,
    server_id      TEXT,
    customer_id    TEXT NOT NULL,
    method         TEXT NOT NULL,               -- phone|visit|message|other
    status         TEXT NOT NULL,               -- collection_status codes
    note           TEXT,
    contacted_at   TEXT NOT NULL,
    next_follow_up TEXT,
    created_at     TEXT NOT NULL,
    sync_status    TEXT NOT NULL DEFAULT 'PENDING',
    FOREIGN KEY (customer_id) REFERENCES customers (id)
  );
  ''',
  '''
  CREATE TABLE IF NOT EXISTS promise_to_pay (
    id                     TEXT PRIMARY KEY,
    server_id              TEXT,
    customer_id            TEXT NOT NULL,
    promised_amount_paisa  INTEGER NOT NULL CHECK (promised_amount_paisa > 0),
    promise_date           TEXT NOT NULL,
    follow_up_date         TEXT,
    customer_note          TEXT,
    status                 TEXT NOT NULL DEFAULT 'open',
    created_at             TEXT NOT NULL,
    sync_status            TEXT NOT NULL DEFAULT 'PENDING',
    FOREIGN KEY (customer_id) REFERENCES customers (id)
  );
  ''',
  'CREATE INDEX IF NOT EXISTS idx_collect_customer ON collection_activities (customer_id);',
  'CREATE INDEX IF NOT EXISTS idx_promise_customer ON promise_to_pay (customer_id);',
  // Direct sales (not tied to a customer): the owner records each sale's amount
  // so daily/monthly/quarterly/yearly totals come from these rows only.
  '''
  CREATE TABLE IF NOT EXISTS sales (
    id           TEXT PRIMARY KEY,
    server_id    TEXT,
    amount_paisa INTEGER NOT NULL CHECK (amount_paisa >= 0),
    note         TEXT,
    sold_at      TEXT NOT NULL,
    sync_status  TEXT NOT NULL DEFAULT 'PENDING'
  );
  ''',
  'CREATE INDEX IF NOT EXISTS idx_sales_soldat ON sales (sold_at);',
  'CREATE INDEX IF NOT EXISTS idx_sales_sync ON sales (sync_status);',
  'CREATE INDEX IF NOT EXISTS idx_sales_server ON sales (server_id);',
];

/// Opens (and creates/migrates) the local database.
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
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE customers ADD COLUMN server_id TEXT;');
        await db.execute('ALTER TABLE transactions ADD COLUMN server_id TEXT;');
        await db.execute(
            'CREATE TABLE IF NOT EXISTS sync_meta (key TEXT PRIMARY KEY, value TEXT);');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_cust_server ON customers (server_id);');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_txn_server ON transactions (server_id);');
      }
      if (oldVersion < 3) {
        // Collection activities + promise-to-pay: their two CREATE TABLEs plus
        // the two indexes that immediately follow them in the schema list.
        await db.execute(kLocalSchema[7]); // collection_activities
        await db.execute(kLocalSchema[8]); // promise_to_pay
        await db.execute(kLocalSchema[9]); // idx_collect_customer
        await db.execute(kLocalSchema[10]); // idx_promise_customer
      }
      if (oldVersion < 4) {
        // The sales table + its three indexes (last four schema statements).
        for (final stmt in kLocalSchema.sublist(kLocalSchema.length - 4)) {
          await db.execute(stmt);
        }
      }
      if (oldVersion < 5) {
        await db.execute('ALTER TABLE customers ADD COLUMN address TEXT;');
      }
    },
  );
}
