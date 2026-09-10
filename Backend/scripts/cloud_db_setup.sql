-- BakiBondhu — cloud database setup.
--
-- Run ONCE against your managed PostgreSQL, as the database's owner/admin user
-- (the one your host gives you), in this order:
--
--   1) psql "<ADMIN_DATABASE_URL>" -f ../../documents/BakiBondhu_PostgreSQL_Schema.sql
--   2) psql "<ADMIN_DATABASE_URL>" -f cloud_db_setup.sql
--
-- The API must connect as this NON-OWNER, NON-SUPERUSER, NOBYPASSRLS role so that
-- row-level security actually isolates each business's data. Connecting as the
-- owner/admin would silently bypass RLS (a cross-tenant data leak), so this step
-- is required, not optional. Your host must let its admin user create a role
-- (Railway / Fly / Supabase superusers can; some providers' default users cannot).
--
-- >>> Replace the password below with a strong one and use the SAME value in the
--     API's ConnectionStrings__App environment variable. <<<

CREATE ROLE bakibondhu_app LOGIN PASSWORD '__SET_A_STRONG_PASSWORD__'
    NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;

GRANT USAGE ON SCHEMA public TO bakibondhu_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO bakibondhu_app;

-- Append-only ledger: the app never deletes, EXCEPT reallocate_customer, which
-- rewrites a customer's payment_allocations. RLS still scopes this to the current
-- tenant, so a targeted DELETE grant is safe.
GRANT DELETE ON payment_allocations TO bakibondhu_app;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO bakibondhu_app;

-- Make the grants apply to any tables/functions added by later migrations too.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO bakibondhu_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO bakibondhu_app;

-- The API's connection string (set as env var ConnectionStrings__App) then looks like:
--   Host=<db-host>;Port=5432;Database=<db-name>;Username=bakibondhu_app;Password=<the password above>;SSL Mode=Require;Trust Server Certificate=true
