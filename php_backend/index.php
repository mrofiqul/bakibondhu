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

    // Latest app versions so installed apps can offer an update (public).
    if ($path === '/api/v1/app/version' && $method === 'GET') {
        bb_json(200, require __DIR__ . '/app_version.php');
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

    // --- Collections & promises (used by the web app; server-backed) ---
    if ($path === '/api/v1/collections' && $method === 'GET') {
        handle_collections_list($cfg);
    }
    if ($path === '/api/v1/collections' && $method === 'POST') {
        handle_collection_add($cfg);
    }
    if ($path === '/api/v1/promises' && $method === 'POST') {
        handle_promise_add($cfg);
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
    if ($path === '/api/v1/admin/export/customers.xlsx' && $method === 'GET') {
        handle_admin_export_customers($cfg);
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
    $thana    = trim((string) ($in['thana'] ?? ''));
    $zila     = trim((string) ($in['zila'] ?? ''));

    if ($name === '' || $phone === '' || $password === '' || $business === '') {
        bb_error(400, 'validation_failed', 'name, phone, password and business_name are required');
    }
    if (!preg_match('/^01[3-9]\d{8}$/', $phone)) {
        bb_error(400, 'validation_failed', 'a valid Bangladesh mobile number is required (01XXXXXXXXX)');
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
    // New shops get a 30-day free trial (reckoned in Bangladesh time so the end
    // date matches the merchant's calendar); the admin can extend or clear it later.
    $trialEnds  = bb_date_in_days_bd(BB_TRIAL_DAYS);

    $db->beginTransaction();
    $db->prepare('INSERT INTO businesses (id, name, timezone, currency, thana, zila, expires_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
       ->execute([$businessId, $business, 'Asia/Dhaka', 'BDT',
                  $thana !== '' ? $thana : null, $zila !== '' ? $zila : null, $trialEnds, $now]);
    $db->prepare('INSERT INTO users (id, business_id, name, phone, password_hash, role, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
       ->execute([$userId, $businessId, $name, $phone, $hash, 'owner', $now]);
    $db->commit();

    bb_json(201, [
        'user'     => ['id' => $userId, 'name' => $name, 'phone' => $phone],
        'business' => ['id' => $businessId, 'name' => $business, 'timezone' => 'Asia/Dhaka', 'currency' => 'BDT', 'expires_at' => $trialEnds],
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
    $stmt = $db->prepare(
        'SELECT u.id, u.business_id, u.role, u.password_hash, b.expires_at
         FROM users u JOIN businesses b ON b.id = u.business_id
         WHERE u.phone = ? LIMIT 1');
    $stmt->execute([$identifier]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password_hash'])) {
        bb_error(401, 'invalid_credentials', 'wrong phone number or password');
    }
    bb_require_active_business($db, $user['business_id']);

    bb_json(200, [
        'role'        => $user['role'],
        'business_id' => $user['business_id'],
        'expires_at'  => $user['expires_at'],  // subscription end (YYYY-MM-DD) or null=unlimited
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
        $op      = (string) ($ch['op'] ?? 'upsert');
        $data    = is_array($ch['data'] ?? null) ? $ch['data'] : [];
        if ($localId === '' || !in_array($entity, ['customer', 'transaction', 'sale', 'collection', 'promise'], true)) {
            $results[] = bb_push_result($entity, $localId, 'FAILED', null, 'bad change');
            continue;
        }

        try {
            if ($entity === 'customer' && $op === 'delete') {
                // Idempotent: removing a customer (and its transactions) that is
                // already gone still succeeds. Scoped to this business.
                bb_delete_customer($db, $businessId, $localId);
                $results[] = bb_push_result($entity, $localId, 'SYNCED', $localId, null);
            } elseif ($entity === 'customer') {
                $serverId = bb_upsert_customer($db, $businessId, $deviceId, $localId, $data);
                $results[] = bb_push_result($entity, $localId, 'SYNCED', $serverId, null);
            } elseif ($entity === 'sale') {
                $serverId = bb_upsert_sale($db, $businessId, $deviceId, $localId, $data);
                $results[] = bb_push_result($entity, $localId, 'SYNCED', $serverId, null);
            } elseif ($entity === 'collection' || $entity === 'promise') {
                $serverId = $entity === 'collection'
                    ? bb_upsert_collection_sync($db, $businessId, $deviceId, $localId, $data)
                    : bb_upsert_promise_sync($db, $businessId, $deviceId, $localId, $data);
                if ($serverId === null) {
                    $results[] = bb_push_result($entity, $localId, 'FAILED', null, 'unknown customer');
                } else {
                    $results[] = bb_push_result($entity, $localId, 'SYNCED', $serverId, null);
                }
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
            // Duplicate customer phone within the shop → surface a clear reason
            // (the client should have prevented it; this covers multi-device).
            $dupPhone = $e->getMessage() === 'duplicate_phone'
                || ($e instanceof PDOException && ($e->errorInfo[1] ?? 0) === 1062);
            $results[] = bb_push_result($entity, $localId,
                $dupPhone ? 'CONFLICT' : 'FAILED', null,
                $dupPhone ? 'duplicate phone in this shop' : 'server error');
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
    $phone   = isset($data['phone']) && $data['phone'] !== '' ? (string) $data['phone'] : null;
    $name    = (string) ($data['name'] ?? '');
    $address = isset($data['address']) && $data['address'] !== '' ? (string) $data['address'] : null;

    $existing = $db->prepare(
        'SELECT id FROM customers WHERE business_id = ? AND device_id = ? AND local_id = ? LIMIT 1');
    $existing->execute([$businessId, $deviceId, $localId]);
    $row = $existing->fetch();
    if (!$row) {
        // Fall back to the server id: a customer created on another device (e.g.
        // the phone) can be edited from the web without a primary-key clash.
        $byId = $db->prepare('SELECT id FROM customers WHERE business_id = ? AND id = ? LIMIT 1');
        $byId->execute([$businessId, $localId]);
        $row = $byId->fetch();
    }
    $serverId = $row ? (string) $row['id'] : $localId;

    // Customer mobile numbers are unique within a shop. The client enforces this
    // too; this is the server backstop (e.g. two devices adding the same number).
    // Another customer (different id) already holding this phone is a conflict —
    // exclude this customer's own id so editing name/address keeps working.
    if ($phone !== null) {
        $dup = $db->prepare(
            'SELECT 1 FROM customers WHERE business_id = ? AND phone = ? AND id <> ? LIMIT 1');
        $dup->execute([$businessId, $phone, $serverId]);
        if ($dup->fetch()) {
            throw new RuntimeException('duplicate_phone');
        }
    }

    if ($row) {
        // Edit: update the profile and bump the pull cursor so other devices see it.
        $db->prepare(
            'UPDATE customers SET name = ?, phone = ?, address = ?, updated_at = UTC_TIMESTAMP(6)
             WHERE id = ?')
           ->execute([$name, $phone, $address, $serverId]);
        return $serverId;
    }

    // New: use the client's local_id as the server id (UUIDs), so the id is
    // stable across devices and a device's pull of its own pushed rows is a no-op.
    $db->prepare(
        'INSERT INTO customers (id, business_id, device_id, local_id, name, phone, address, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(6))')
       ->execute([
           $serverId, $businessId, $deviceId, $localId, $name, $phone, $address,
           gmdate('Y-m-d H:i:s'),
       ]);
    return $serverId;
}

// Delete a customer (and its transactions) within a business. Idempotent: a
// missing customer is a no-op. The server id == the client local id.
function bb_delete_customer(PDO $db, string $businessId, string $localId): void
{
    $db->prepare('DELETE FROM transactions WHERE business_id = ? AND customer_id = ?')
       ->execute([$businessId, $localId]);
    $db->prepare('DELETE FROM customers WHERE business_id = ? AND id = ?')
       ->execute([$businessId, $localId]);
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

// Normalize an ISO-8601 timestamp to a MySQL DATETIME string. Null/'' -> null.
function bb_mysql_dt($iso): ?string
{
    $s = trim((string) ($iso ?? ''));
    if ($s === '') return null;
    return substr(rtrim(str_replace('T', ' ', $s), 'Z'), 0, 26);
}
// Keep just the Y-m-d date part (for DATE columns). Null/'' -> null.
function bb_date_only($v): ?string
{
    $s = trim((string) ($v ?? ''));
    return $s === '' ? null : substr($s, 0, 10);
}

// Insert a collection activity from sync push (idempotent on business+device+
// local). Resolves the client's customer id; null if that customer isn't synced.
function bb_upsert_collection_sync(PDO $db, string $businessId, string $deviceId, string $localId, array $data): ?string
{
    $existing = $db->prepare('SELECT id FROM collection_activities WHERE business_id = ? AND device_id = ? AND local_id = ? LIMIT 1');
    $existing->execute([$businessId, $deviceId, $localId]);
    if ($row = $existing->fetch()) return (string) $row['id'];

    $customerId = bb_resolve_customer_id($db, $businessId, $deviceId, (string) ($data['customer_local_id'] ?? ''));
    if ($customerId === null) return null;

    $db->prepare(
        'INSERT INTO collection_activities
           (id, business_id, device_id, local_id, customer_id, method, status, note, next_follow_up, contacted_at, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(6))')
       ->execute([$localId, $businessId, $deviceId, $localId, $customerId,
           (string) ($data['method'] ?? 'other'), (string) ($data['status'] ?? 'contacted'),
           ($data['note'] ?? '') !== '' ? (string) $data['note'] : null,
           bb_date_only($data['next_follow_up'] ?? null),
           bb_mysql_dt($data['contacted_at'] ?? null) ?? gmdate('Y-m-d H:i:s'),
           gmdate('Y-m-d H:i:s')]);
    return $localId;
}

// Insert a promise-to-pay from sync push (idempotent). Null if customer unknown.
function bb_upsert_promise_sync(PDO $db, string $businessId, string $deviceId, string $localId, array $data): ?string
{
    $existing = $db->prepare('SELECT id FROM promise_to_pay WHERE business_id = ? AND device_id = ? AND local_id = ? LIMIT 1');
    $existing->execute([$businessId, $deviceId, $localId]);
    if ($row = $existing->fetch()) return (string) $row['id'];

    $customerId = bb_resolve_customer_id($db, $businessId, $deviceId, (string) ($data['customer_local_id'] ?? ''));
    if ($customerId === null) return null;

    $db->prepare(
        'INSERT INTO promise_to_pay
           (id, business_id, device_id, local_id, customer_id, amount_paisa, promise_date, follow_up_date, status, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(6))')
       ->execute([$localId, $businessId, $deviceId, $localId, $customerId,
           (int) ($data['amount_paisa'] ?? 0), bb_date_only($data['promise_date'] ?? null),
           bb_date_only($data['follow_up_date'] ?? null), (string) ($data['status'] ?? 'open'),
           gmdate('Y-m-d H:i:s')]);
    return $localId;
}

// GET /api/v1/sync/pull?since=<cursor>&device_id=<id> — everything changed after
// the cursor. Reply: { customers:[…], transactions:[…], sales:[…], collections:[…],
// promises:[…], server_time, has_more }.
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
    $collections  = bb_pull_rows($db, 'collection_activities', $businessId, $since, $serverTime, $limit);
    $promises     = bb_pull_rows($db, 'promise_to_pay', $businessId, $since, $serverTime, $limit);

    $out = ['customers' => [], 'transactions' => [], 'sales' => [], 'collections' => [], 'promises' => []];
    foreach ($customers as $r) {
        $out['customers'][] = [
            'id'         => $r['id'],
            'name'       => $r['name'],
            'phone'      => $r['phone'],
            'address'    => $r['address'],
            'created_at' => isset($r['created_at']) ? (string) $r['created_at'] : null,
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
    foreach ($collections as $r) {
        $out['collections'][] = [
            'id'             => $r['id'],
            'customer_id'    => $r['customer_id'],
            'method'         => $r['method'],
            'status'         => $r['status'],
            'note'           => $r['note'],
            'next_follow_up' => $r['next_follow_up'],
            'contacted_at'   => $r['contacted_at'],
            'updated_at'     => bb_iso_utc($r['updated_at']),
        ];
    }
    foreach ($promises as $r) {
        $out['promises'][] = [
            'id'             => $r['id'],
            'customer_id'    => $r['customer_id'],
            'amount_paisa'   => (int) $r['amount_paisa'],
            'promise_date'   => $r['promise_date'],
            'follow_up_date' => $r['follow_up_date'],
            'status'         => $r['status'],
            'updated_at'     => bb_iso_utc($r['updated_at']),
        ];
    }

    $out['server_time'] = $serverTime;
    $out['has_more']    = (count($customers) >= $limit) || (count($transactions) >= $limit) || (count($sales) >= $limit)
        || (count($collections) >= $limit) || (count($promises) >= $limit);
    // Current subscription end so the app can show a trial-ending reminder; the
    // admin may have changed it since login. null = unlimited.
    $exp = $db->prepare('SELECT expires_at FROM businesses WHERE id = ? LIMIT 1');
    $exp->execute([$businessId]);
    $out['expires_at'] = $exp->fetchColumn() ?: null;
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

// ---- Collections & promises -------------------------------------------------
// Server-backed for the web app. (The Android app keeps these local-only for now;
// unifying them into sync is a later step.) All scoped to the caller's business.

function bb_customer_in_business(PDO $db, string $businessId, string $customerId): bool
{
    $st = $db->prepare('SELECT 1 FROM customers WHERE business_id = ? AND id = ? LIMIT 1');
    $st->execute([$businessId, $customerId]);
    return (bool) $st->fetchColumn();
}

// GET /api/v1/collections?customer_id=… — a customer's activities + promises.
function handle_collections_list(array $cfg): void
{
    $claims     = bb_auth($cfg);
    $businessId = (string) $claims['business_id'];
    $customerId = trim((string) ($_GET['customer_id'] ?? ''));
    if ($customerId === '') bb_error(400, 'validation_failed', 'customer_id is required');
    $db = bb_db($cfg);
    bb_require_active_business($db, $businessId);

    $a = $db->prepare(
        'SELECT id, method, status, note, next_follow_up, contacted_at
         FROM collection_activities WHERE business_id = ? AND customer_id = ?
         ORDER BY contacted_at DESC');
    $a->execute([$businessId, $customerId]);
    $p = $db->prepare(
        'SELECT id, amount_paisa, promise_date, follow_up_date, status
         FROM promise_to_pay WHERE business_id = ? AND customer_id = ?
         ORDER BY created_at DESC');
    $p->execute([$businessId, $customerId]);

    $activities = [];
    foreach ($a as $r) {
        $activities[] = [
            'id' => $r['id'], 'method' => $r['method'], 'status' => $r['status'],
            'note' => $r['note'], 'next_follow_up' => $r['next_follow_up'],
            'contacted_at' => $r['contacted_at'],
        ];
    }
    $promises = [];
    foreach ($p as $r) {
        $promises[] = [
            'id' => $r['id'], 'amount_paisa' => (int) $r['amount_paisa'],
            'promise_date' => $r['promise_date'], 'follow_up_date' => $r['follow_up_date'],
            'status' => $r['status'],
        ];
    }
    bb_json(200, ['activities' => $activities, 'promises' => $promises]);
}

// POST /api/v1/collections — record a collection activity.
function handle_collection_add(array $cfg): void
{
    $claims     = bb_auth($cfg);
    $businessId = (string) $claims['business_id'];
    $in = bb_body();
    $customerId = trim((string) ($in['customer_id'] ?? ''));
    $method     = trim((string) ($in['method'] ?? ''));
    $status     = trim((string) ($in['status'] ?? ''));
    if ($customerId === '' || $method === '' || $status === '') {
        bb_error(400, 'validation_failed', 'customer_id, method and status are required');
    }
    $db = bb_db($cfg);
    bb_require_active_business($db, $businessId);
    if (!bb_customer_in_business($db, $businessId, $customerId)) {
        bb_error(404, 'not_found', 'no such customer');
    }
    $id   = bb_uuid();
    $note = isset($in['note']) && $in['note'] !== '' ? (string) $in['note'] : null;
    $next = isset($in['next_follow_up']) && $in['next_follow_up'] !== '' ? (string) $in['next_follow_up'] : null;
    $db->prepare(
        'INSERT INTO collection_activities
           (id, business_id, device_id, local_id, customer_id, method, status, note, next_follow_up, contacted_at, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(6), ?, UTC_TIMESTAMP(6))')
       ->execute([$id, $businessId, 'web', $id, $customerId, $method, $status, $note, $next, gmdate('Y-m-d H:i:s')]);
    bb_json(201, ['ok' => true, 'id' => $id]);
}

// POST /api/v1/promises — record a promise to pay.
function handle_promise_add(array $cfg): void
{
    $claims     = bb_auth($cfg);
    $businessId = (string) $claims['business_id'];
    $in = bb_body();
    $customerId  = trim((string) ($in['customer_id'] ?? ''));
    $amount      = (int) ($in['amount_paisa'] ?? 0);
    $promiseDate = trim((string) ($in['promise_date'] ?? ''));
    if ($customerId === '' || $amount <= 0 || $promiseDate === '') {
        bb_error(400, 'validation_failed', 'customer_id, amount_paisa and promise_date are required');
    }
    $db = bb_db($cfg);
    bb_require_active_business($db, $businessId);
    if (!bb_customer_in_business($db, $businessId, $customerId)) {
        bb_error(404, 'not_found', 'no such customer');
    }
    $id     = bb_uuid();
    $follow = isset($in['follow_up_date']) && $in['follow_up_date'] !== '' ? (string) $in['follow_up_date'] : null;
    $db->prepare(
        'INSERT INTO promise_to_pay
           (id, business_id, device_id, local_id, customer_id, amount_paisa, promise_date, follow_up_date, status, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, UTC_TIMESTAMP(6))')
       ->execute([$id, $businessId, 'web', $id, $customerId, $amount, $promiseDate, $follow, 'open', gmdate('Y-m-d H:i:s')]);
    bb_json(201, ['ok' => true, 'id' => $id]);
}
