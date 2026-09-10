# Deploy the BakiBondhu backend — Render (app) + Neon (PostgreSQL)

Both have genuinely-free tiers, give HTTPS, and (unlike free shared hosting) allow
normal API access. End result: Login/Register work on any phone, anywhere.

You create the two accounts (I can't sign up for you). I do the config, SQL,
env vars, testing, and the app rebuild.

---

## Part 1 — Neon (the database)

1. Go to **neon.tech** → **Sign up** (Google/GitHub login, free, no card).
2. It creates a project with a PostgreSQL database. Open **Dashboard → Connection Details**
   and copy the connection string — it looks like:
   `postgresql://<owner>:<password>@ep-xxxx.<region>.aws.neon.tech/<dbname>?sslmode=require`
3. Open **SQL Editor** (left menu). We'll run two things there (I'll give you the exact
   text once I see your project):
   - the schema (`documents/BakiBondhu_PostgreSQL_Schema.sql`)
   - the app-role setup (`Backend/scripts/cloud_db_setup.sql`, adapted for Neon)
   The app connects as a **non-owner role** so row-level security isolates each
   business's data.

➡️ **Send me:** the full Neon connection string from step 2. (I'll turn it into the
exact `ConnectionStrings__App` value Render needs, using the non-owner role.)

---

## Part 2 — Get the code on GitHub (Render deploys from a repo)

Render builds from a Git repository. The repo already has the `Dockerfile` and
`render.yaml`.

- If you have a **GitHub account**: I can push this project to a new **private** repo
  for you — just run `gh auth login` once in the terminal (or create an empty repo
  named `bakibondhu` and tell me), and I'll push.
- No GitHub yet? Create a free account at **github.com**, then do the above.

➡️ **Tell me:** your GitHub username, and run `gh auth login` (pick GitHub.com → HTTPS
→ login with browser). Then I push.

---

## Part 3 — Render (the app)

1. Go to **render.com** → **Sign up** (free; log in with GitHub to link your repos).
2. **New → Blueprint** → pick your `bakibondhu` repo → Render reads `render.yaml` and
   proposes the **bakibondhu-api** web service (Docker, free plan, health check
   `/health`). Click **Apply**.
3. When it asks for the two secret env vars (or in the service's **Environment** tab),
   set:
   - `ConnectionStrings__App` = (the value I give you from your Neon string)
   - `Jwt__Key` = (I'll give you a long random one)
   - `Jwt__Issuer` is already `bakibondhu`.
4. Render builds the Dockerfile and deploys. You get a URL like
   `https://bakibondhu-api.onrender.com`.

➡️ **Send me:** your Render URL. I'll hit `/health`, run a live register + login, then
rebuild the APK pointed at it.

---

## Notes
- **Free tier sleeps** after ~15 min idle, so the first request after a pause takes
  ~30–50s to wake (then it's fast). Fine for personal use; a paid tier removes it.
- Neon free is generous and permanent for a small DB.
- Secrets (`Jwt__Key`, DB password) live only in Render's env vars — never in git.
