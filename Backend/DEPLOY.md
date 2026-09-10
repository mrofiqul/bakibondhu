# Deploying the BakiBondhu backend to the cloud

Goal: run the API + PostgreSQL on the internet with HTTPS, so **Login/Register work
on any phone, anywhere** — no PC required.

Everything the app needs is already here:
- `Dockerfile` — builds and runs the API in a container (any host).
- `scripts/cloud_db_setup.sql` — creates the non-owner DB role that row-level
  security requires.
- The API reads its secrets from environment variables:
  - `ConnectionStrings__App` — the PostgreSQL connection string
  - `Jwt__Key` — a long random signing key (≥ 32 bytes)
  - `Jwt__Issuer` — `bakibondhu` (optional; this is the default)
  - `PORT` — injected by the host; the app binds to it automatically

> **What you must do yourself:** create the hosting account and enter any billing
> details. I can't sign up or pay on your behalf. Everything else (config, schema,
> the app rebuild) I can do with you.

---

## Recommended host: Railway

Railway is the smoothest for this stack and its PostgreSQL gives you an admin role
that **can create the RLS app-role** (some hosts' default DB users can't — see the
note at the bottom). Fly.io and Supabase also work; Render's free Postgres user
often cannot create roles, so avoid it unless you upgrade.

### 1. Create the database
1. Sign up at railway.app → **New Project** → **Provision PostgreSQL**.
2. Open the Postgres service → **Variables/Connect** → copy the **connection URL**
   (looks like `postgresql://postgres:...@...railway.app:5432/railway`).

### 2. Load the schema + app role
On your PC (PostgreSQL client tools installed — `psql`), run from `Backend/scripts`:
```
psql "<ADMIN_CONNECTION_URL>" -f ../../documents/BakiBondhu_PostgreSQL_Schema.sql
psql "<ADMIN_CONNECTION_URL>" -f cloud_db_setup.sql
```
Before running the second file, edit it and replace `__SET_A_STRONG_PASSWORD__`
with a strong password (keep it — you'll need it next).

### 3. Deploy the API
Easiest without GitHub — use the Railway CLI from the `Backend/` folder:
```
npm i -g @railway/cli
railway login
railway link          # pick the project you created
railway up            # builds the Dockerfile and deploys
```
Then in the Railway dashboard → your API service → **Variables**, add:
- `ConnectionStrings__App` =
  `Host=<db-host>;Port=5432;Database=<db-name>;Username=bakibondhu_app;Password=<the password from step 2>;SSL Mode=Require;Trust Server Certificate=true`
- `Jwt__Key` = a long random string (≥ 32 chars) — ask me and I'll generate one
- `Jwt__Issuer` = `bakibondhu`

Under **Settings → Networking**, click **Generate Domain** to get a public HTTPS URL,
e.g. `https://bakibondhu-api-production.up.railway.app`.

### 4. Verify
```
curl https://<your-domain>/health
```
Expect `{"status":"ok",...}`. Then a real register:
```
curl -X POST https://<your-domain>/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","phone":"01700000000","password":"secret123","business_name":"Test Shop"}'
```
Expect HTTP 201 with a token.

### 5. Point the app at the cloud
Rebuild the APK against your HTTPS domain (I'll do this once you share the URL):
```
flutter build apk --release --split-per-abi \
  --dart-define=SYNC_BASE_URL=https://<your-domain>
```
Install that APK — Login/Register now work on any network, on any phone.

---

## Notes
- **Keep secrets out of git.** `Jwt__Key` and the DB password live only in the host's
  environment variables, never in the repo. `appsettings.Development.json` (dev-only)
  is already gitignored from the image via `.dockerignore`.
- **Why a separate DB role?** The API connects as `bakibondhu_app`
  (NOSUPERUSER, NOBYPASSRLS) so PostgreSQL row-level security isolates each
  business's data. Connecting as the admin/owner would bypass RLS — a cross-tenant
  leak — so step 2 is mandatory.
- **Free tiers sleep.** Some free plans spin the service down when idle, so the first
  request after a pause is slow (cold start). Fine for testing; use a paid tier for
  real users.
- **HTTPS is required** by Android for cleartext-free networking; all these hosts
  give HTTPS automatically, so we can drop `usesCleartextTraffic` for the cloud build.
