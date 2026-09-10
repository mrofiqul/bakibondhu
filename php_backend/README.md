# BakiBondhu — PHP + MySQL auth backend (for freehosting.com / cPanel)

A tiny, dependency-free PHP backend that implements the app's **register** and
**login** endpoints, so Login/Register work on any phone once it's online. It
matches the app's existing API contract exactly — the app only needs its base URL
pointed here.

**Endpoints**
- `GET  /health` — quick check, returns `{"status":"ok",...}`
- `POST /api/v1/auth/register` — body `{name, phone, password, business_name}`
- `POST /api/v1/auth/login` — body `{identifier, password}` (identifier = phone)

> Scope: this covers **auth only**. Cloud **sync** still needs the .NET+Postgres
> backend (shared hosting can't run it). So on freehosting you can log in/register
> from anywhere; multi-device sync comes later via a proper host.

---

## Deploy on cPanel (freehosting.com)

### 1. Create the MySQL database
cPanel → **MySQL Databases**:
1. Create a database (note its full name, e.g. `youracct_bakibondhu`).
2. Create a user + password.
3. **Add the user to the database** with **All Privileges**.

### 2. Import the tables
cPanel → **phpMyAdmin** → pick your database → **Import** → upload `schema.sql` → Go.

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
