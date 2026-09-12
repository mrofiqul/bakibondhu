<?php
// One-time admin bootstrap. Create the FIRST platform admin by choosing a
// username + password in your browser (over HTTPS). It only works while no
// admin exists yet. DELETE this file once your admin account is created.
require __DIR__ . '/lib.php';
$cfg = require __DIR__ . '/config.php';

if (!hash_equals('bb_setup_2026', $_GET['key'] ?? '')) { http_response_code(403); exit('forbidden'); }

$db = bb_db($cfg);
$already = (int) $db->query('SELECT COUNT(*) FROM admins')->fetchColumn() > 0;

$msg = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if ($already) {
        $msg = 'An admin already exists. For security, delete this file (admin_setup.php).';
    } else {
        $u = trim((string) ($_POST['username'] ?? ''));
        $p = (string) ($_POST['password'] ?? '');
        if ($u === '' || strlen($p) < 8) {
            $msg = 'Username required and password must be at least 8 characters.';
        } else {
            $db->prepare('INSERT INTO admins (id, username, password_hash, created_at) VALUES (?, ?, ?, ?)')
               ->execute([bb_uuid(), $u, password_hash($p, PASSWORD_BCRYPT), gmdate('Y-m-d H:i:s')]);
            $already = true;
            $msg = 'Admin "' . htmlspecialchars($u) . '" created. Now DELETE admin_setup.php, then open /admin to log in.';
        }
    }
}
?><!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Admin setup</title>
<style>
  body{font:15px/1.5 system-ui,sans-serif;background:#f4f5f8;color:#1a1d24;display:grid;place-items:center;min-height:100vh;margin:0}
  .box{background:#fff;border:1px solid #e3e6ec;border-radius:16px;padding:26px;width:min(380px,92vw);box-shadow:0 6px 24px rgba(20,25,40,.08)}
  h1{font-size:18px;margin:0 0 4px} p{color:#606875;margin:0 0 16px}
  label{font-size:13px;font-weight:600;display:block;margin:12px 0 4px}
  input{width:100%;padding:10px;border:1px solid #cfd4de;border-radius:8px;font:inherit;box-sizing:border-box}
  button{margin-top:18px;width:100%;padding:11px;background:#3f4ea3;color:#fff;border:none;border-radius:8px;font:inherit;font-weight:600;cursor:pointer}
  .msg{margin-top:14px;padding:10px 12px;border-radius:8px;background:#eef1fb;color:#2b3a80;font-size:14px}
</style></head><body>
<div class="box">
  <h1>বাকিবন্ধু · Admin setup</h1>
  <p>Create the platform administrator account.</p>
  <?php if ($msg): ?><div class="msg"><?= $msg ?></div><?php endif; ?>
  <?php if (!$already): ?>
  <form method="post">
    <label>Username</label>
    <input name="username" autocomplete="username" required>
    <label>Password (min 8 characters)</label>
    <input name="password" type="password" autocomplete="new-password" required minlength="8">
    <button type="submit">Create admin</button>
  </form>
  <?php endif; ?>
</div></body></html>
