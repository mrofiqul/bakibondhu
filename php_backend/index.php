<?php
// BakiBondhu PHP backend — front controller.
// Routes: GET /health, POST /api/v1/auth/register, POST /api/v1/auth/login.
// Mirrors the .NET API's request/response contract so the Flutter app is
// unchanged apart from its base URL.

require __DIR__ . '/lib.php';
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

    bb_json(200, [
        'role'        => $user['role'],
        'business_id' => $user['business_id'],
        'tokens'      => bb_tokens($cfg, $user['id'], $user['business_id'], $user['role']),
    ]);
}
