-- BakiBondhu — dev database setup (run as the postgres superuser).
--
-- Full local setup:
--   createdb -U postgres bakibondhu
--   psql -U postgres -d bakibondhu -f ../../documents/BakiBondhu_PostgreSQL_Schema.sql
--   psql -U postgres -d bakibondhu -f dev_db_setup.sql
--
-- The API connects as this NON-OWNER, NON-SUPERUSER role so row-level security
-- actually binds (a superuser/owner would bypass RLS). Migrations run as the
-- owner (postgres); the app never does.

CREATE ROLE bakibondhu_app LOGIN PASSWORD 'app_pw'
    NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;

GRANT USAGE ON SCHEMA public TO bakibondhu_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO bakibondhu_app;

-- Append-only ledger: the app never deletes, EXCEPT that reallocate_customer
-- rewrites a customer's payment_allocations. RLS still scopes this to the
-- current tenant, so a targeted DELETE grant here is safe.
GRANT DELETE ON payment_allocations TO bakibondhu_app;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO bakibondhu_app;

-- Connection string used by the API (appsettings.Development.json):
--   Host=localhost;Port=5432;Database=bakibondhu;Username=bakibondhu_app;Password=app_pw
