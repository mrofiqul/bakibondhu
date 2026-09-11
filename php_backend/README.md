# BakiBondhu — PHP + MySQL backend (auth + sync, for InfinityFree / cPanel)

A tiny, dependency-free PHP backend that implements the app's **register**,
**login**, and **offline-sync** endpoints, so Login/Register and cloud sync work on
any phone once it's online. It matches the app's existing API contract exactly —
the app only needs its base URL pointed here.

**Endpoints**
- `GET  /health` — quick check, returns `{"status":"ok",...}`
- `POST /api/v1/auth/register` — body `{name, phone, password, business_name}`
- `POST /api/v1/auth/login` — body `{identifier, password}` (identifier = phone)
- `POST /api/v1/sync/push` — upload local changes (Bearer token). Body
  `{device_id, changes:[{entity,local_id,op,data}]}` →
  `{results:[{entity,local_id,server_id,sync_status,reason}]}`
- `GET  /api/v1/sync/pull?since=<cursor>&device_id=<id>` — download changes
  (Bearer token) → `{customers:[…], transactions:[…], server_time, has_more}`

### How sync works
- **Auth:** the sync endpoints require the `Authorization: Bearer <access_token>`
  the app got from register/login; the business (tenant) is read from the JWT.
- **Idempotent:** each change is deduped on `(business_id, device_id, local_id)`,
  and the **server id equals the client's local id** (both UUIDs), so replays and a
  device pulling back its own pushes are harmless no-ops.
- **Append-only:** v1 only creates rows (`op: "create"`); balances are recomputed
  on the device. A transaction whose customer hasn't synced yet returns `FAILED`
  and simply retries on the next sync (customers push first).
- **Cursor:** `pull` returns rows with `updated_at` after `since` (server clock,
  microsecond precision); the app stores `server_time` and passes it back next time.

---

## Deploy on cPanel (freehosting.com)

### 1. Create the MySQL database
cPanel → **MySQL Databases**:
1. Create a database (note its full name, e.g. `youracct_bakibondhu`).
2. Create a user + password.
3. **Add the user to the database** with **All Privileges**.

### 2. Import the tables
cPanel → **phpMyAdmin** → pick your database → **Import** → upload `schema.sql` → Go.
`schema.sql` uses `CREATE TABLE IF NOT EXISTS`, so re-importing it on an existing
database is safe and simply adds the new `customers` + `transactions` sync tables.

### 3. Edit config.php
Open `config.php` and fill in:
- `db_name`, `db_user`, `db_pass` from step 1 (`db_host` stays `localhost`)
- `jwt_secret` — a long random string (I generated one for you; ask if you need it)

### 4. Upload the files
cPanel → **File Manager** → `public_html` → upload **all** of these into the root
of `public_html` (so the API is served at your domain root):
```
index.php   lib.php   config.php   .htaccess   schema.sql
```
(You can delete `schema.sql` after importing; it isn't used at runtime.)

### 5. Test
In a browser, open `https://YOUR-DOMAIN/health` → you should see
`{"status":"ok",...}`. If you instead see the file listing or a 404, `.htaccess`
rewriting may be off — tell me and I'll switch to a no-rewrite layout.

### 6. Point the app here
Tell me your domain (e.g. `https://yourname.freehosting.com`) and I'll rebuild the
APK with that URL. Then Register/Login on the phone will hit this backend.

---

## Notes
- Passwords are stored **bcrypt-hashed** (`password_hash`); never in plain text.
- `config.php` holds secrets — the included `.htaccess` blocks it from being served,
  and it must never be committed to git or shared.
- Requires **HTTPS** for safe password transport. Free cPanel hosts usually provide
  AutoSSL on your subdomain; if yours is HTTP-only, tell me and we'll handle it.
- **Token lifetime:** there's no refresh flow, so `config.php`'s `jwt_ttl_sec`
  should be long (the sample uses 30 days) or shopkeepers get logged out between
  syncs. Bump it in `config.php` on the host if it's still the old `3600`.
- **Authorization header:** the `.htaccess` forwards `Authorization` to PHP (Apache
  strips it by default). If sync returns 401 with a valid login, that rule isn't
  taking effect on your host — tell me and I'll switch to a header fallback.
