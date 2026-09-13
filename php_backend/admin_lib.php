<?php
// BakiBondhu — super-admin panel backend (platform-wide reports + management).
// Included by index.php. Auth is a separate admin JWT (scope=admin), distinct
// from the per-business user tokens. Every mutating action is audit-logged.

const BB_ADMIN_TTL = 28800; // admin session 8h (powerful token → shorter life)

// ---- admin auth -----------------------------------------------------------

function bb_admin_token(array $cfg, string $adminId, string $username): array
{
    $now = time();
    $token = bb_jwt([
        'sub'      => $adminId,
        'username' => $username,
        'scope'    => 'admin',
        'jti'      => bb_uuid(),
        'iat'      => $now,
        'exp'      => $now + BB_ADMIN_TTL,
        'iss'      => $cfg['jwt_issuer'],
        'aud'      => $cfg['jwt_issuer'],
    ], $cfg['jwt_secret']);
    return ['access_token' => $token, 'access_expires_in' => BB_ADMIN_TTL];
}

// Require a valid admin token; returns claims or sends 401/403.
function bb_admin_auth(array $cfg): array
{
    $tok = bb_bearer_token();
    $claims = $tok ? bb_jwt_verify($tok, $cfg['jwt_secret']) : null;
    if (!$claims || ($claims['scope'] ?? '') !== 'admin') {
        bb_error(401, 'unauthorized', 'admin login required');
    }
    return $claims;
}

function bb_admin_audit(PDO $db, string $adminId, string $action, ?string $target = null, ?string $detail = null): void
{
    $db->prepare('INSERT INTO admin_audit (admin_id, action, target, detail, at) VALUES (?, ?, ?, ?, UTC_TIMESTAMP(6))')
       ->execute([$adminId, $action, $target, $detail]);
}

// Number of shops whose subscription has expired. Tolerant of the older schema
// (no expires_at column) → reports 0 so the overview never breaks.
function bb_expired_count(PDO $db): int
{
    try {
        return (int) $db->query(
            "SELECT COUNT(*) FROM businesses WHERE expires_at IS NOT NULL AND expires_at < UTC_DATE()"
        )->fetchColumn();
    } catch (Throwable $e) {
        return 0;
    }
}

// ---- login ----------------------------------------------------------------

function handle_admin_login(array $cfg): void
{
    $in = bb_body();
    $username = trim((string) ($in['username'] ?? ''));
    $password = (string) ($in['password'] ?? '');
    if ($username === '' || $password === '') {
        bb_error(400, 'validation_failed', 'username and password are required');
    }

    $db = bb_db($cfg);
    $stmt = $db->prepare('SELECT id, username, password_hash FROM admins WHERE username = ? LIMIT 1');
    $stmt->execute([$username]);
    $admin = $stmt->fetch();

    if (!$admin || !password_verify($password, $admin['password_hash'])) {
        bb_error(401, 'invalid_credentials', 'wrong username or password');
    }
    $db->prepare('UPDATE admins SET last_login = ? WHERE id = ?')
       ->execute([gmdate('Y-m-d H:i:s'), $admin['id']]);

    bb_json(200, [
        'admin'  => ['id' => $admin['id'], 'username' => $admin['username']],
        'tokens' => bb_admin_token($cfg, $admin['id'], $admin['username']),
    ]);
}

// ---- reports --------------------------------------------------------------

// GET /api/v1/admin/overview — platform-wide KPIs, trends, recent activity.
function handle_admin_overview(array $cfg): void
{
    bb_admin_auth($cfg);
    $db = bb_db($cfg);

    $count = fn(string $t) => (int) $db->query("SELECT COUNT(*) FROM $t")->fetchColumn();

    // Outstanding credit across the whole platform (credit - payment), in paisa.
    $outstanding = (int) $db->query(
        "SELECT COALESCE(SUM(CASE WHEN type='credit' THEN amount_paisa
                                  WHEN type='payment' THEN -amount_paisa
                                  WHEN type='adjustment_debit' THEN amount_paisa
                                  WHEN type='adjustment_credit' THEN -amount_paisa
                                  ELSE 0 END), 0) FROM transactions")->fetchColumn();

    // Signups per day, last 14 days.
    $signups = $db->query(
        "SELECT DATE(created_at) AS d, COUNT(*) AS c
         FROM businesses
         WHERE created_at >= (UTC_TIMESTAMP() - INTERVAL 14 DAY)
         GROUP BY DATE(created_at) ORDER BY d")->fetchAll();

    // Recent transactions (admin sees all tenants).
    $recent = $db->query(
        "SELECT t.type, t.amount_paisa, t.note, t.updated_at, c.name AS customer, b.name AS shop
         FROM transactions t
         JOIN customers c ON c.id = t.customer_id
         JOIN businesses b ON b.id = t.business_id
         ORDER BY t.updated_at DESC LIMIT 12")->fetchAll();

    bb_json(200, [
        'totals' => [
            'businesses'   => $count('businesses'),
            'users'        => $count('users'),
            'customers'    => $count('customers'),
            'transactions' => $count('transactions'),
            'sales_count'  => $count('sales'),
            'suspended'    => (int) $db->query("SELECT COUNT(*) FROM businesses WHERE status='suspended'")->fetchColumn(),
            'expired'      => bb_expired_count($db),
            'outstanding_paisa' => $outstanding,
            'sales_paisa'  => (int) $db->query("SELECT COALESCE(SUM(amount_paisa),0) FROM sales")->fetchColumn(),
        ],
        'signups_14d' => $signups,
        'recent'      => $recent,
        'server_time' => gmdate('c'),
    ]);
}

// GET /api/v1/admin/businesses — every shop with per-shop stats.
function handle_admin_businesses(array $cfg): void
{
    bb_admin_auth($cfg);
    $db = bb_db($cfg);

    $rows = $db->query(
        "SELECT b.id, b.name, b.status, b.expires_at, b.created_at,
                (SELECT COUNT(*) FROM users u      WHERE u.business_id = b.id) AS users,
                (SELECT COUNT(*) FROM customers c  WHERE c.business_id = b.id) AS customers,
                (SELECT COUNT(*) FROM transactions t WHERE t.business_id = b.id) AS transactions,
                (SELECT COALESCE(SUM(CASE WHEN type='credit' THEN amount_paisa
                                          WHEN type='payment' THEN -amount_paisa
                                          WHEN type='adjustment_debit' THEN amount_paisa
                                          WHEN type='adjustment_credit' THEN -amount_paisa
                                          ELSE 0 END),0)
                 FROM transactions t WHERE t.business_id = b.id) AS outstanding_paisa,
                (SELECT COALESCE(SUM(amount_paisa),0) FROM sales s WHERE s.business_id = b.id) AS sales_paisa
         FROM businesses b
         ORDER BY b.created_at DESC")->fetchAll();

    bb_json(200, ['businesses' => $rows]);
}

// GET /api/v1/admin/business?id=... — one shop: its users, customers+balances.
function handle_admin_business_detail(array $cfg): void
{
    bb_admin_auth($cfg);
    $id = (string) ($_GET['id'] ?? '');
    if ($id === '') bb_error(400, 'validation_failed', 'id is required');

    $db = bb_db($cfg);
    $bStmt = $db->prepare('SELECT id, name, status, expires_at, created_at FROM businesses WHERE id = ? LIMIT 1');
    $bStmt->execute([$id]);
    $business = $bStmt->fetch();
    if (!$business) bb_error(404, 'not_found', 'no such business');

    $users = $db->prepare('SELECT id, name, phone, role, created_at FROM users WHERE business_id = ? ORDER BY created_at');
    $users->execute([$id]);

    $customers = $db->prepare(
        "SELECT c.id, c.name, c.phone, c.address,
                COALESCE(SUM(CASE WHEN t.type='credit' THEN t.amount_paisa
                                  WHEN t.type='payment' THEN -t.amount_paisa
                                  WHEN t.type='adjustment_debit' THEN t.amount_paisa
                                  WHEN t.type='adjustment_credit' THEN -t.amount_paisa
                                  ELSE 0 END),0) AS balance_paisa,
                COUNT(t.id) AS txn_count
         FROM customers c
         LEFT JOIN transactions t ON t.customer_id = c.id
         WHERE c.business_id = ?
         GROUP BY c.id ORDER BY balance_paisa DESC");
    $customers->execute([$id]);

    bb_json(200, [
        'business'  => $business,
        'users'     => $users->fetchAll(),
        'customers' => $customers->fetchAll(),
    ]);
}

// ---- actions --------------------------------------------------------------

// POST /api/v1/admin/action  { action, id, [password] }
function handle_admin_action(array $cfg): void
{
    $claims  = bb_admin_auth($cfg);
    $adminId = (string) $claims['sub'];
    $in      = bb_body();
    $action  = (string) ($in['action'] ?? '');
    $id      = (string) ($in['id'] ?? '');
    if ($id === '') bb_error(400, 'validation_failed', 'id is required');

    $db = bb_db($cfg);

    switch ($action) {
        case 'suspend_business':
        case 'unsuspend_business': {
            $status = $action === 'suspend_business' ? 'suspended' : 'active';
            $n = $db->prepare('UPDATE businesses SET status = ? WHERE id = ?');
            $n->execute([$status, $id]);
            if ($n->rowCount() === 0) bb_error(404, 'not_found', 'no such business');
            bb_admin_audit($db, $adminId, $action, $id);
            bb_json(200, ['ok' => true, 'status' => $status]);
        }

        case 'set_expiry': {
            // expires_at: 'YYYY-MM-DD' to set a date, or '' / null to make unlimited.
            $raw = $in['expires_at'] ?? null;
            $expires = null;
            if (is_string($raw) && trim($raw) !== '') {
                $raw = trim($raw);
                $d = DateTime::createFromFormat('!Y-m-d', $raw);
                $errors = DateTime::getLastErrors();
                if (!$d || ($errors && ($errors['warning_count'] || $errors['error_count']))) {
                    bb_error(400, 'validation_failed', 'expires_at must be YYYY-MM-DD');
                }
                $expires = $d->format('Y-m-d');
            }
            $n = $db->prepare('UPDATE businesses SET expires_at = ? WHERE id = ?');
            $n->execute([$expires, $id]);
            if ($n->rowCount() === 0) {
                // rowCount is 0 when the value is unchanged too; confirm the shop exists.
                $chk = $db->prepare('SELECT 1 FROM businesses WHERE id = ? LIMIT 1');
                $chk->execute([$id]);
                if (!$chk->fetchColumn()) bb_error(404, 'not_found', 'no such business');
            }
            bb_admin_audit($db, $adminId, 'set_expiry', $id, $expires ?? 'unlimited');
            bb_json(200, ['ok' => true, 'expires_at' => $expires]);
        }

        case 'delete_business': {
            $exists = $db->prepare('SELECT name FROM businesses WHERE id = ? LIMIT 1');
            $exists->execute([$id]);
            $name = $exists->fetchColumn();
            if ($name === false) bb_error(404, 'not_found', 'no such business');
            $db->beginTransaction();
            foreach (['transactions','customers','sales','users'] as $t) {
                $db->prepare("DELETE FROM $t WHERE business_id = ?")->execute([$id]);
            }
            $db->prepare('DELETE FROM businesses WHERE id = ?')->execute([$id]);
            $db->commit();
            bb_admin_audit($db, $adminId, 'delete_business', $id, (string) $name);
            bb_json(200, ['ok' => true]);
        }

        case 'delete_user': {
            $u = $db->prepare('SELECT phone FROM users WHERE id = ? LIMIT 1');
            $u->execute([$id]);
            $phone = $u->fetchColumn();
            if ($phone === false) bb_error(404, 'not_found', 'no such user');
            $db->prepare('DELETE FROM users WHERE id = ?')->execute([$id]);
            bb_admin_audit($db, $adminId, 'delete_user', $id, (string) $phone);
            bb_json(200, ['ok' => true]);
        }

        case 'reset_password': {
            $newPass = (string) ($in['password'] ?? '');
            if (strlen($newPass) < 6) bb_error(400, 'validation_failed', 'new password must be at least 6 characters');
            $hash = password_hash($newPass, PASSWORD_BCRYPT);
            $n = $db->prepare('UPDATE users SET password_hash = ? WHERE id = ?');
            $n->execute([$hash, $id]);
            if ($n->rowCount() === 0) bb_error(404, 'not_found', 'no such user');
            bb_admin_audit($db, $adminId, 'reset_password', $id);
            bb_json(200, ['ok' => true]);
        }

        default:
            bb_error(400, 'validation_failed', 'unknown action');
    }
}

// GET /api/v1/admin/audit — recent admin actions.
function handle_admin_audit_log(array $cfg): void
{
    bb_admin_auth($cfg);
    $db = bb_db($cfg);
    $rows = $db->query(
        "SELECT a.action, a.target, a.detail, a.at, ad.username
         FROM admin_audit a LEFT JOIN admins ad ON ad.id = a.admin_id
         ORDER BY a.at DESC LIMIT 50")->fetchAll();
    bb_json(200, ['audit' => $rows]);
}
