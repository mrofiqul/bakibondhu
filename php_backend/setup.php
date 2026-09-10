<?php
// One-time schema setup — creates the tables from *inside* the server, which is
// needed on hosts (like InfinityFree) that block outside MySQL connections.
//
// Visit once:  https://YOUR-DOMAIN/setup.php?key=<the jwt_secret from config.php>
// Delete this file afterwards.

require __DIR__ . '/lib.php';
$cfg = require __DIR__ . '/config.php';

if (($_GET['key'] ?? '') !== $cfg['jwt_secret']) {
    http_response_code(403);
    header('Content-Type: text/plain');
    echo "forbidden — pass ?key=<jwt_secret>";
    exit;
}

try {
    $db = bb_db($cfg);
    $db->exec(
        "CREATE TABLE IF NOT EXISTS businesses (
            id         CHAR(36)     NOT NULL,
            name       VARCHAR(200) NOT NULL,
            timezone   VARCHAR(64)  NOT NULL DEFAULT 'Asia/Dhaka',
            currency   VARCHAR(8)   NOT NULL DEFAULT 'BDT',
            created_at DATETIME     NOT NULL,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );
    $db->exec(
        "CREATE TABLE IF NOT EXISTS users (
            id            CHAR(36)     NOT NULL,
            business_id   CHAR(36)     NOT NULL,
            name          VARCHAR(200) NOT NULL,
            phone         VARCHAR(32)  NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            role          VARCHAR(32)  NOT NULL DEFAULT 'owner',
            created_at    DATETIME     NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY uq_users_phone (phone),
            KEY idx_users_business (business_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );
    header('Content-Type: text/plain');
    echo "setup ok — tables 'businesses' and 'users' are ready. Now DELETE setup.php.";
} catch (Throwable $e) {
    http_response_code(500);
    header('Content-Type: text/plain');
    echo "setup failed: " . $e->getMessage();
}
