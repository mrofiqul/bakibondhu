<?php
// BakiBondhu PHP backend — shared helpers: DB, JSON I/O, UUID, JWT (HS256).
// Vanilla PHP, no external dependencies (works on basic shared hosting).

function bb_db(array $cfg): PDO
{
    $dsn = "mysql:host={$cfg['db_host']};dbname={$cfg['db_name']};charset=utf8mb4";
    return new PDO($dsn, $cfg['db_user'], $cfg['db_pass'], [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ]);
}

// Read and JSON-decode the request body into an associative array.
function bb_body(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === '' || $raw === false) return [];
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

function bb_json(int $status, array $payload): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

function bb_error(int $status, string $code, string $message): void
{
    bb_json($status, ['error' => ['code' => $code, 'message' => $message]]);
}

// RFC-4122 v4 UUID.
function bb_uuid(): string
{
    $b = random_bytes(16);
    $b[6] = chr((ord($b[6]) & 0x0f) | 0x40);
    $b[8] = chr((ord($b[8]) & 0x3f) | 0x80);
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($b), 4));
}

function bb_base64url(string $data): string
{
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

// Minimal HS256 JWT (header.payload.signature) — same shape the .NET API issues,
// so the token stays valid if the app later syncs against a JWT backend.
function bb_jwt(array $claims, string $secret): string
{
    $header  = bb_base64url(json_encode(['alg' => 'HS256', 'typ' => 'JWT']));
    $payload = bb_base64url(json_encode($claims));
    $sig     = bb_base64url(hash_hmac('sha256', "$header.$payload", $secret, true));
    return "$header.$payload.$sig";
}

function bb_base64url_decode(string $data): string
{
    $pad = strlen($data) % 4;
    if ($pad) $data .= str_repeat('=', 4 - $pad);
    return base64_decode(strtr($data, '-_', '+/'));
}

// Verify an HS256 JWT and return its claims, or null if invalid/expired.
function bb_jwt_verify(string $token, string $secret): ?array
{
    $parts = explode('.', $token);
    if (count($parts) !== 3) return null;
    [$h, $p, $s] = $parts;

    $expected = bb_base64url(hash_hmac('sha256', "$h.$p", $secret, true));
    if (!hash_equals($expected, $s)) return null;

    $claims = json_decode(bb_base64url_decode($p), true);
    if (!is_array($claims)) return null;
    if (isset($claims['exp']) && time() >= (int) $claims['exp']) return null;

    return $claims;
}

// Pull the Bearer token off the request (shared hosting strips Authorization from
// $_SERVER unless the .htaccess passes it through, so check several places).
function bb_bearer_token(): ?string
{
    $header = '';
    if (function_exists('apache_request_headers')) {
        foreach (apache_request_headers() as $k => $v) {
            if (strcasecmp($k, 'Authorization') === 0) { $header = $v; break; }
        }
    }
    if ($header === '') {
        $header = $_SERVER['HTTP_AUTHORIZATION']
            ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    }
    if ($header !== '' && preg_match('/Bearer\s+(.+)/i', $header, $m)) {
        return trim($m[1]);
    }
    return null;
}

// Require a valid token; returns its claims (sub, business_id, role) or 401s.
function bb_auth(array $cfg): array
{
    $token = bb_bearer_token();
    $claims = $token ? bb_jwt_verify($token, $cfg['jwt_secret']) : null;
    if (!$claims || empty($claims['business_id'])) {
        bb_error(401, 'unauthorized', 'a valid access token is required');
    }
    return $claims;
}

// Build the token response block the Flutter app reads (tokens.access_token …).
function bb_tokens(array $cfg, string $userId, string $businessId, string $role): array
{
    $now = time();
    $token = bb_jwt([
        'sub'         => $userId,
        'business_id' => $businessId,
        'role'        => $role,
        'jti'         => bb_uuid(),
        'iat'         => $now,
        'exp'         => $now + (int) $cfg['jwt_ttl_sec'],
        'iss'         => $cfg['jwt_issuer'],
        'aud'         => $cfg['jwt_issuer'],
    ], $cfg['jwt_secret']);

    return ['access_token' => $token, 'access_expires_in' => (int) $cfg['jwt_ttl_sec']];
}
