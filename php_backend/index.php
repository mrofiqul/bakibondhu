<?php
// BakiBondhu PHP backend — front controller.
// Routes: GET /health, POST /api/v1/auth/register, POST /api/v1/auth/login.
// Mirrors the .NET API's request/response contract so the Flutter app is
// unchanged apart from its base URL.

require __DIR__ . '/lib.php';
require __DIR__ . '/admin_lib.php';
$cfg = require __DIR__ . '/config.php';

// --- CORS (so the future web app can call this too) ---
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// Path without query string, and with any subfolder the app is installed under
// stripped so "/api/v1/auth/login" matches regardless of install location.
$uri  = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$path = '/' . ltrim($uri, '/');
if (($pos = strpos($path, '/api/')) !== false) {
    $path = substr($path, $pos); // normalise to start at /api/...
}
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    if ($path === '/health' || $path === '/api/v1/ping') {
        bb_json(200, ['status' => 'ok', 'service' => 'bakibondhu-php', 'time' => gmdate('c')]);
    }

    if ($path === '/api/v1/auth/register' && $method === 'POST') {
        handle_register($cfg);
    }

    if ($path === '/api/v1/auth/login' && $method === 'POST') {
        handle_login($cfg);
    }

    if ($path === '/api/v1/sync/push' && $method === 'POST') {
        handle_sync_push($cfg);
    }

    if ($path === '/api/v1/sync/pull' && $method === 'GET') {
        handle_sync_pull($cfg);
    }

    // --- Admin panel (super-admin; see admin_lib.php) ---
    if ($path === '/api/v1/admin/login' && $method === 'POST') {
        handle_admin_login($cfg);
    }
    if ($path === '/api/v1/admin/overview' && $method === 'GET') {
        handle_admin_overview($cfg);
    }
    if ($path === '/api/v1/admin/businesses' && $method === 'GET') {
        handle_admin_businesses($cfg);
    }
    if ($path === '/api/v1/admin/business' && $method === 'GET') {
        handle_admin_business_detail($cfg);
    }
    if ($path === '/api/v1/admin/action' && $method === 'POST') {
        handle_admin_action($cfg);
    }
    if ($path === '/api/v1/admin/audit' && $method === 'GET') {
        handle_admin_audit_log($cfg);
    }

    bb_error(404, 'not_found', 'no such endpoint');
} catch (Throwable $e) {
    // Don't leak internals; log server-side.
    error_log('BakiBondhu API error: ' . $e->getMessage());
    bb_error(500, 'server_error', 'something went wrong');
}

function handle_register(array $cfg): void
{
    $in = bb_body();
    $name     = trim((string) ($in['name'] ?? ''));
    $phone    = trim((string) ($in['phone'] ?? ''));
    $password = (string) ($in['password'] ?? '');
    $business = trim((string) ($in['business_name'] ?? ''));

    if ($phone === '' || $password === '' || $business === '') {
        bb_error(400, 'validation_failed', 'phone, password and business_name are required');
    }
    if (strlen($password) < 6) {
        bb_error(400, 'validation_failed', 'password must be at least 6 characters');
    }

    $db = bb_db($cfg);

    $exists = $db->prepare('SELECT 1 FROM users WHERE phone = ? LIMIT 1');
    $exists->execute([$phone]);
    if ($exists->fetch()) {
        bb_error(409, 'conflict', 'this phone number is already registered');
    }

    $businessId = bb_uuid();
    $userId     = bb_uuid();
    $now        = gmdate('Y-m-d H:i:s');
    $hash       = password_hash($password, PASSWORD_BCRYPT);

    $db->beginTransaction();
    $db->prepare('INSERT INTO businesses (id, name, timezone, currency, created_at) VALUES (?, ?, ?, ?, ?)')
       ->execute([$businessId, $business, 'Asia/Dhaka', 'BDT', $now]);
    $db->prepare('INSERT INTO users (id, business_id, name, phone, password_hash, role, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
       ->execute([$userId, $businessId, $name !== '' ? $name : $business, $phone, $hash, 'owner', $now]);
    $db->commit();

    bb_json(201, [
        'user'     => ['id' => $userId, 'name' => $name, 'phone' => $phone],
        'business' => ['id' => $businessId, 'name' => $business, 'timezone' => 'Asia/Dhaka', 'currency' => 'BDT'],
        'role'     => 'owner',
        'tokens'   => bb_tokens($cfg, $userId, $businessId, 'owner'),
    ]);
}

function handle_login(array $cfg): void
{
    $in = bb_body();
    $identifier = trim((string) ($in['identifier'] ?? ''));
    $password   = (string) ($in['password'] ?? '');

    if ($identifier === '' || $password === '') {
        bb_error(400, 'validation_failed', 'identifier and password are required');
    }

    $db = bb_db($cfg);
    $stmt = $db->prepare('SELECT id, business_id, role, password_hash FROM users WHERE phone = ? LIMIT 1');
    $stmt->execute([$identifier]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password_hash'])) {
        bb_error(401, 'invalid_credentials', 'wrong phone number or password');
    }
    bb_require_active_business($db, $user['business_id']);

    bb_json(200, [
        'role'        => $user['role'],
        'business_id' => $user['business_id'],
        'tokens'      => bb_tokens($cfg, $user['id'], $user['business_id'], $user['role']),
    ]);
}

// ---- Sync (Offline Sync design; contract in Android_App/lib/sync) -----------

// POST /api/v1/sync/push — upload locally-created changes. Idempotent on
// (business_id, device_id, local_id); replays return the same server id.
// Body: { device_id, changes:[{entity,local_id,op,data}] }
// Reply: { results:[{entity,local_id,server_id,sync_status,reason}] }
function handle_sync_push(array $cfg): void
{
    $claims     = bb_auth($cfg);
    $businessId = (string) $claims['business_id'];

    $in       = bb_body();
    $deviceId = trim((string) ($in['device_id'] ?? ''));
    $changes  = is_array($in['changes'] ?? null) ? $in['changes'] : [];
    if ($deviceId === '') {
        bb_error(400, 'validation_failed', 'device_id is required');
    }

    $db      = bb_db($cfg);
    bb_require_active_business($db, $businessId);
    $results = [];

    foreach ($changes as $ch) {
        $entity  = (string) ($ch['entity'] ?? '');
        $localId = (string) ($ch['local_id'] ?? '');
        $data    = is_array($ch['data'] ?? null) ? $ch['data'] : [];
        if ($localId === '' || !in_array($entity, ['customer', 'transaction', 'sale'], true)) {
            $results[] = bb_push_result($entity, $localId, 'FAILED', null, 'bad change');
            continue;
        }

        try {
            if ($entity === 'customer') {
                $serverId = bb_upsert_customer($db, $businessId, $deviceId, $localId, $data);
                $results[] = bb_push_result($entity, $localId, 'SYNCED', $serverId, null);
            } elseif ($entity === 'sale') {
                $serverId = bb_upsert_sale($db, $businessId, $deviceId, $localId, $data);
                $results[] = bb_push_result($entity, $localId, 'SYNCED', $serverId, null);
            } else {
                $serverId = bb_upsert_transaction($db, $businessId, $deviceId, $localId, $data);
                if ($serverId === null) {
                    // Customer not on the server yet — retry after it syncs.
                    $results[] = bb_push_result($entity, $localId, 'FAILED', null, 'unknown customer');
                } else {
                    $results[] = bb_push_result($entity, $localId, 'SYNCED', $serverId, null);
                }
            }
        } catch (Throwable $e) {
            error_log('sync push item failed: ' . $e->getMessage());
            $results[] = bb_push_result($entity, $localId, 'FAILED', null, 'server error');
        }
    }

    bb_json(200, ['results' => $results]);
}

function bb_push_result(string $entity, string $localId, string $status, ?string $serverId, ?string $reason): array
{
    return [
        'entity'      => $entity,
        'local_id'    => $localId,
        'server_id'   => $serverId,
        'sync_status' => $status,
        'reason'      => $reason,
    ];
}

// Insert a customer (idempotent). Returns the server id (existing on replay).
function bb_upsert_customer(PDO $db, string $businessId, string $deviceId, string $localId, array $data): string
{
    $existing = $db->prepare(
        'SELECT id FROM customers WHERE business_id = ? AND device_id = ? AND local_id = ? LIMIT 1');
    $existing->execute([$businessId, $deviceId, $localId]);
    if ($row = $existing->fetch()) {
        return (string) $row['id'];
    }

    // Use the client's local_id as the server id: local ids are UUIDs, so this
    // keeps the id stable across devices and makes a device's pull of its own
    // pushed rows a harmless no-op (no id remapping needed on the client).
    $serverId = $localId;
    $db->prepare(
        'INSERT INTO customers (id, business_id, device_id, local_id, name, phone, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(6))')
       ->execute([
           $serverId, $businessId, $deviceId, $localId,
           (string) ($data['name'] ?? ''),
           isset($data['phone']) && $data['phone'] !== '' ? (string) $data['phone'] : null,
           gmdate('Y-m-d H:i:s'),
       ]);
    return $serverId;
}

// Insert a transaction (idempotent). Resolves the client's customer_local_id to
// a server customer id. Returns null if that customer isn't on the server yet.
function bb_upsert_transaction(PDO $db, string $businessId, string $deviceId, string $localId, array $data): ?string
{
    $existing = $db->prepare(
        'SELECT id FROM transactions WHERE business_id = ? AND device_id = ? AND local_id = ? LIMIT 1');
    $existing->execute([$businessId, $deviceId, $localId]);
    if ($row = $existing->fetch()) {
        return (string) $row['id'];
    }

    $customerLocalId = (string) ($data['customer_local_id'] ?? '');
    $customerId = bb_resolve_customer_id($db, $businessId, $deviceId, $customerLocalId);
    if ($customerId === null) {
        return null;
    }

    // Server id == the client's local id (see bb_upsert_customer).
    $serverId = $localId;
    $db->prepare(
        'INSERT INTO transactions
           (id, business_id, device_id, local_id, customer_id, type, amount_paisa, due_date, note, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(6))')
       ->execute([
           $serverId, $businessId, $deviceId, $localId, $customerId,
           (string) ($data['type'] ?? 'credit'),
           (int) ($data['amount_paisa'] ?? 0),
           isset($data['due_date']) && $data['due_date'] !== '' ? (string) $data['due_date'] : null,
           isset($data['note']) && $data['note'] !== '' ? (string) $data['note'] : null,
           isset($data['created_at']) && $data['created_at'] !== '' ? (string) $data['created_at'] : gmdate('Y-m-d H:i:s'),
       ]);
    return $serverId;
}

// A transaction's customer_local_id is either the client's local id for a
// customer created on THIS device, or (for a customer that was pulled from the
// server) already a server id. Try both.
function bb_resolve_customer_id(PDO $db, string $businessId, string $deviceId, string $localId): ?string
{
    if ($localId === '') return null;

    $byLocal = $db->prepare(
        'SELECT id FROM customers WHERE business_id = ? AND device_id = ? AND local_id = ? LIMIT 1');
    $byLocal->execute([$businessId, $deviceId, $localId]);
    if ($row = $byLocal->fetch()) return (string) $row['id'];

    $byServer = $db->prepare(
        'SELECT id FROM customers WHERE business_id = ? AND id = ? LIMIT 1');
    $byServer->execute([$businessId, $localId]);
    if ($row = $byServer->fetch()) return (string) $row['id'];

    return null;
}

// Insert a sale (idempotent; server id == client local_id). No customer.
function bb_upsert_sale(PDO $db, string $businessId, string $deviceId, string $localId, array $data): string
{
    $existing = $db->prepare(
        'SELECT id FROM sales WHERE business_id = ? AND device_id = ? AND local_id = ? LIMIT 1');
    $existing->execute([$businessId, $deviceId, $localId]);
    if ($row = $existing->fetch()) {
        return (string) $row['id'];
    }

    $serverId = $localId;
    $db->prepare(
        'INSERT INTO sales (id, business_id, device_id, local_id, amount_paisa, note, sold_at, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(6))')
       ->execute([
           $serverId, $businessId, $deviceId, $localId,
           (int) ($data['amount_paisa'] ?? 0),
           isset($data['note']) && $data['note'] !== '' ? (string) $data['note'] : null,
           isset($data['sold_at']) && $data['sold_at'] !== '' ? (string) $data['sold_at'] : gmdate('Y-m-d H:i:s'),
           gmdate('Y-m-d H:i:s'),
       ]);
    return $serverId;
}

// GET /api/v1/sync/pull?since=<cursor>&device_id=<id> — everything changed after
// the cursor. Reply: { customers:[…], transactions:[…], sales:[…], server_time, has_more }.
function handle_sync_pull(array $cfg): void
{
    $claims     = bb_auth($cfg);
    $businessId = (string) $claims['business_id'];
    $since      = isset($_GET['since']) && $_GET['since'] !== '' ? (string) $_GET['since'] : null;

    $db = bb_db($cfg);
    bb_require_active_business($db, $businessId);

    // Cursor snapshot taken before reading, so rows written during this request
    // are simply picked up next pull (never skipped).
    $serverTime = (string) $db->query('SELECT UTC_TIMESTAMP(6)')->fetchColumn();

    $limit = 5000;

    $customers    = bb_pull_rows($db, 'customers', $businessId, $since, $serverTime, $limit);
    $transactions = bb_pull_rows($db, 'transactions', $businessId, $since, $serverTime, $limit);
    $sales        = bb_pull_rows($db, 'sales', $businessId, $since, $serverTime, $limit);

    $out = ['customers' => [], 'transactions' => [], 'sales' => []];
    foreach ($customers as $r) {
        $out['customers'][] = [
            'id'         => $r['id'],
            'name'       => $r['name'],
            'phone'      => $r['phone'],
            'updated_at' => bb_iso_utc($r['updated_at']),
        ];
    }
    foreach ($transactions as $r) {
        $out['transactions'][] = [
            'id'           => $r['id'],
            'customer_id'  => $r['customer_id'],
            'type'         => $r['type'],
            'amount_paisa' => (int) $r['amount_paisa'],
            'due_date'     => $r['due_date'],
            'note'         => $r['note'],
            'updated_at'   => bb_iso_utc($r['updated_at']),
        ];
    }
    foreach ($sales as $r) {
        $out['sales'][] = [
            'id'           => $r['id'],
            'amount_paisa' => (int) $r['amount_paisa'],
            'note'         => $r['note'],
            'sold_at'      => $r['sold_at'],
            'updated_at'   => bb_iso_utc($r['updated_at']),
        ];
    }

    $out['server_time'] = $serverTime;
    $out['has_more']    = (count($customers) >= $limit) || (count($transactions) >= $limit) || (count($sales) >= $limit);
    bb_json(200, $out);
}

function bb_pull_rows(PDO $db, string $table, string $businessId, ?string $since, string $upTo, int $limit): array
{
    if ($since === null) {
        $stmt = $db->prepare(
            "SELECT * FROM $table WHERE business_id = ? AND updated_at <= ?
             ORDER BY updated_at ASC LIMIT $limit");
        $stmt->execute([$businessId, $upTo]);
    } else {
        $stmt = $db->prepare(
            "SELECT * FROM $table WHERE business_id = ? AND updated_at > ? AND updated_at <= ?
             ORDER BY updated_at ASC LIMIT $limit");
        $stmt->execute([$businessId, $since, $upTo]);
    }
    return $stmt->fetchAll();
}

// MySQL DATETIME(6) "Y-m-d H:i:s.u" (UTC) -> ISO-8601 with T…Z so Dart's
// DateTime.parse reads it as UTC.
function bb_iso_utc(string $mysqlDateTime): string
{
    return str_replace(' ', 'T', $mysqlDateTime) . 'Z';
}
