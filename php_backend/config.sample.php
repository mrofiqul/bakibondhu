<?php
// BakiBondhu PHP backend — configuration.
//
// EDIT the values below after you create your MySQL database in cPanel, then
// upload this file with the others. Keep this file private (never share it).

return [
    // --- MySQL (from cPanel → "MySQL Databases") ---
    // Free cPanel hosts usually prefix the names, e.g. "youracct_bakibondhu".
    'db_host' => 'localhost',          // almost always "localhost" on shared hosting
    'db_name' => 'REPLACE_DB_NAME',    // e.g. youracct_bakibondhu
    'db_user' => 'REPLACE_DB_USER',    // e.g. youracct_bbuser
    'db_pass' => 'REPLACE_DB_PASSWORD',

    // --- JWT signing (any long random string, >= 32 chars) ---
    // Ask the assistant for a generated one, or make your own. Keep it secret.
    'jwt_secret'  => 'REPLACE_WITH_A_LONG_RANDOM_SECRET_AT_LEAST_32_CHARS',
    'jwt_issuer'  => 'bakibondhu',
    // Access-token lifetime. This backend has no refresh flow, so keep it long
    // enough that shopkeepers aren't forced to re-login between syncs.
    'jwt_ttl_sec' => 2592000, // 30 days
];
