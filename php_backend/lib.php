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
