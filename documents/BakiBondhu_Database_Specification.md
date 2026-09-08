# BakiBondhu — PostgreSQL Database Specification

**Version 1.0** · rev. 2026-09-08 · Target PostgreSQL 13+ (validated on 17)
Companion to the Application Specification (v1.1). Markdown companion to the `.docx`; the runnable schema is `BakiBondhu_PostgreSQL_Schema.sql`.

---

## 1. Overview

Complete, runnable PostgreSQL schema: enum types, tables, keys and indexes, computed balance/aging views, append-only ledger triggers, FIFO payment allocation (`reallocate_customer`), tenant-isolation row-level security, and seed data. Validated end-to-end on PostgreSQL 17 (`psql -f`, `ON_ERROR_STOP`).

**Design principles:** multi-tenant isolation by `business_id` (§5); append-only ledger with reversal/adjustment (§15); balances COMPUTED, never stored (§15); offline sync fields (§17); money `NUMERIC(14,2)`; `timestamptz` UTC displayed Asia/Dhaka; UUID keys for offline id-generation (§19).

**Rev 2026-09-08:** RLS policies use `NULLIF(current_setting(...),'')::uuid` so an unset/empty tenant GUC denies access instead of erroring (pooled-connection safety). The application connects as a non-owner role — see `Backend/scripts/dev_db_setup.sql`.

## 2. Complete schema (runnable)

```sql
-- =====================================================================
-- BakiBondhu — PostgreSQL Database Specification
-- Version 1.0  ·  rev. 2026-09-07 (spec-review fixes)  ·  Target: PostgreSQL 13+
-- Companion to: BakiBondhu Android & Web Application Specification (v1.1)
--
-- Rev 2026-09-07 (from specification review):
--   · payment_allocations added; customer_aging now ages the UNPAID portion of each
--     credit and uses the business timezone, so it reconciles with customer_balances
--   · RLS: FORCE enabled + dedicated non-owner app-role guidance; business_users moved
--     to a user-scoped membership policy (plain tenant isolation broke multi-business login)
--   · promise_to_pay gained offline sync fields (local_id, device_id, sync_status)
--
-- Design principles (from the app spec):
--   · Multi-tenant: every business row is isolated by business_id (Section 5)
--   · Append-only financial ledger; corrections via reversal/adjustment (Section 15)
--   · Customer balance is COMPUTED, never stored (Section 15)
--   · Offline-first sync fields on synced entities (Section 17)
--   · Money is NUMERIC(14,2) — never floating point
--   · Timestamps stored as timestamptz (UTC); displayed in Asia/Dhaka (Section 15)
--   · UUID primary keys so the Android app can generate ids offline (Section 19)
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- provides gen_random_uuid()

-- =====================================================================
-- 1. ENUM TYPES
-- =====================================================================
CREATE TYPE sync_status        AS ENUM ('LOCAL','PENDING','SYNCED','FAILED','CONFLICT');          -- Section 17
CREATE TYPE contact_method     AS ENUM ('phone','visit','message','other');                        -- Section 8.8
CREATE TYPE collection_status  AS ENUM ('not_contacted','contacted','promise_to_pay',
                                         'partially_paid','paid','refused_disputed','follow_up_required');
CREATE TYPE promise_status     AS ENUM ('open','fulfilled','partial','broken');                    -- Section 8.9
CREATE TYPE reminder_channel   AS ENUM ('sms','whatsapp');
CREATE TYPE reminder_status    AS ENUM ('queued','sent','delivered','failed');                     -- Section 34
CREATE TYPE subscription_status AS ENUM ('trialing','active','past_due','cancelled','expired');
CREATE TYPE entity_status      AS ENUM ('active','inactive','suspended');

-- =====================================================================
-- 2. LOOKUP / PLATFORM TABLES  (not tenant-scoped)
-- =====================================================================

CREATE TABLE plans (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code           TEXT UNIQUE NOT NULL,          -- 'free' | 'pro' | 'business'
    name           TEXT NOT NULL,
    price_monthly  NUMERIC(10,2) NOT NULL DEFAULT 0,   -- in BDT
    currency       CHAR(3) NOT NULL DEFAULT 'BDT',
    limits         JSONB NOT NULL DEFAULT '{}',    -- e.g. {"max_users":1,"max_customers":null}
    features       JSONB NOT NULL DEFAULT '{}',
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE plans IS 'Subscription plans (Section 24). Free / Pro / Business.';

CREATE TABLE roles (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code         TEXT UNIQUE NOT NULL,            -- owner|manager|sales_rep|collection_officer|sysadmin
    name         TEXT NOT NULL,
    permissions  JSONB NOT NULL DEFAULT '{}',
    is_system    BOOLEAN NOT NULL DEFAULT TRUE
);
COMMENT ON TABLE roles IS 'Role definitions & permission sets (Section 6).';

CREATE TABLE transaction_types (
    code         TEXT PRIMARY KEY,                -- 'credit'|'payment'|'adjustment_debit'|'adjustment_credit'
    name         TEXT NOT NULL,
    -- effect on receivable balance: +1 increases owed, -1 decreases owed, 0 = neutral/manual
    balance_sign SMALLINT NOT NULL CHECK (balance_sign IN (-1,0,1))
);
COMMENT ON TABLE transaction_types IS 'Section 18/19. Drives how each transaction affects the balance.';

-- =====================================================================
-- 3. IDENTITY & TENANCY
-- =====================================================================

CREATE TABLE users (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name           TEXT NOT NULL,
    phone          VARCHAR(20) UNIQUE,            -- primary login for BD users (Section 38: phone+OTP)
    email          TEXT UNIQUE,
    password_hash  TEXT,                          -- nullable when OTP-only
    status         entity_status NOT NULL DEFAULT 'active',
    last_login_at  TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (phone IS NOT NULL OR email IS NOT NULL)
);
COMMENT ON TABLE users IS 'Global user identities. A user may belong to many businesses via business_users.';

CREATE TABLE businesses (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name           TEXT NOT NULL,
    owner_user_id  UUID NOT NULL REFERENCES users(id),
    phone          VARCHAR(20),
    address        TEXT,
    area           TEXT,
    timezone       TEXT NOT NULL DEFAULT 'Asia/Dhaka',
    currency       CHAR(3) NOT NULL DEFAULT 'BDT',
    status         entity_status NOT NULL DEFAULT 'active',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE businesses IS 'The tenant root (Section 5). Every tenant row references businesses.id.';

CREATE TABLE business_users (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id      UUID NOT NULL REFERENCES roles(id),
    status       entity_status NOT NULL DEFAULT 'active',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (business_id, user_id)
);
COMMENT ON TABLE business_users IS 'Membership + role of a user within a business (Section 5/6).';

-- =====================================================================
-- 4. CUSTOMERS
-- =====================================================================

CREATE TABLE customers (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id         UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_code       TEXT,                         -- optional human code, unique per business
    name                TEXT NOT NULL,                -- Section 8.4: required
    phone               VARCHAR(20),
    alt_contact         VARCHAR(20),
    address             TEXT,
    area                TEXT,
    customer_type       TEXT,
    credit_limit        NUMERIC(14,2),
    default_due_days    INTEGER,
    assigned_sales_rep_id UUID,                        -- FK added after sales_representatives
    notes               TEXT,
    messaging_consent   BOOLEAN NOT NULL DEFAULT FALSE, -- Section 34: consent before messaging
    do_not_message      BOOLEAN NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    -- sync fields (Section 17)
    local_id            UUID,
    device_id           UUID,
    sync_status         sync_status NOT NULL DEFAULT 'SYNCED',
    created_by          UUID REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (business_id, customer_code)
);
COMMENT ON TABLE customers IS 'Section 8.4. One row per customer, isolated by business_id.';

CREATE TABLE customer_contacts (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id  UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    type         TEXT NOT NULL,                    -- 'mobile' | 'alt' | 'whatsapp' | ...
    value        VARCHAR(40) NOT NULL,
    is_primary   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================================================
-- 5. SALES REPS & ASSIGNMENTS  (Distributor Edition — Section 11/25 Phase 3)
-- =====================================================================

CREATE TABLE sales_representatives (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES users(id),
    code         TEXT,
    territory    TEXT,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (business_id, user_id)
);

ALTER TABLE customers
    ADD CONSTRAINT fk_customers_sales_rep
    FOREIGN KEY (assigned_sales_rep_id) REFERENCES sales_representatives(id);

CREATE TABLE customer_assignments (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id    UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id    UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    sales_rep_id   UUID NOT NULL REFERENCES sales_representatives(id) ON DELETE CASCADE,
    assigned_by    UUID REFERENCES users(id),
    assigned_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    unassigned_at  TIMESTAMPTZ,
    UNIQUE (business_id, customer_id, sales_rep_id, assigned_at)
);

-- =====================================================================
-- 6. TRANSACTIONS  (append-only ledger — Sections 15 & 19)
-- =====================================================================

CREATE TABLE transactions (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),   -- server_id
    local_id                 UUID,                                         -- client-generated (Section 17)
    business_id              UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id              UUID NOT NULL REFERENCES customers(id),
    transaction_type_code    TEXT NOT NULL REFERENCES transaction_types(code),
    amount                   NUMERIC(14,2) NOT NULL CHECK (amount >= 0),   -- sign comes from type
    transaction_date         TIMESTAMPTZ NOT NULL DEFAULT now(),
    due_date                 DATE,
    invoice_reference        TEXT,
    payment_method           TEXT,                                         -- payments only
    receipt_reference        TEXT,
    note                     TEXT,
    created_by               UUID REFERENCES users(id),
    collected_by             UUID REFERENCES users(id),                    -- payments (Section 8.7)
    device_id                UUID,
    reversal_of_transaction_id UUID REFERENCES transactions(id),           -- correction link (Section 15)
    sync_status              sync_status NOT NULL DEFAULT 'SYNCED',
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- idempotency: a given client transaction lands once even if retried (Section 21)
    UNIQUE (business_id, device_id, local_id)
);
COMMENT ON TABLE transactions IS
  'Append-only. Never DELETE or edit amount/type; correct via reversal/adjustment rows (Section 15).';

-- =====================================================================
-- 6b. PAYMENT ALLOCATIONS  (payment → credit application, for correct aging)
-- =====================================================================
-- A payment (or credit adjustment) is applied against one or more outstanding
-- credits so that aging reflects the UNPAID portion of each credit. The app should
-- allocate FIFO (oldest due_date first) at payment time. Balances do NOT depend on
-- this table (balance = Σ amount × balance_sign); allocations only ATTRIBUTE payments
-- to credits so customer_aging reconciles with customer_balances.
CREATE TABLE payment_allocations (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id    UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    payment_txn_id UUID NOT NULL REFERENCES transactions(id),   -- payment / adjustment_credit
    credit_txn_id  UUID NOT NULL REFERENCES transactions(id),   -- the credit being settled
    amount         NUMERIC(14,2) NOT NULL CHECK (amount > 0),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (payment_txn_id, credit_txn_id)
);
COMMENT ON TABLE payment_allocations IS
  'Applies payments to specific credits (FIFO) so aging reflects unpaid credit. Does not affect balances.';

-- =====================================================================
-- 7. COLLECTION WORKFLOW
-- =====================================================================

CREATE TABLE collection_activities (              -- Section 8.8
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id       UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id       UUID NOT NULL REFERENCES customers(id),
    contacted_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    method            contact_method NOT NULL,
    status            collection_status NOT NULL,
    note              TEXT,
    next_follow_up_at DATE,
    created_by        UUID REFERENCES users(id),
    local_id          UUID,
    device_id         UUID,
    sync_status       sync_status NOT NULL DEFAULT 'SYNCED',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE promise_to_pay (                     -- Section 8.9
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id      UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id      UUID NOT NULL REFERENCES customers(id),
    promised_amount  NUMERIC(14,2) NOT NULL CHECK (promised_amount > 0),
    promise_date     DATE NOT NULL,
    follow_up_date   DATE,
    customer_note    TEXT,
    actual_payment   NUMERIC(14,2),
    status           promise_status NOT NULL DEFAULT 'open',
    created_by       UUID REFERENCES users(id),
    -- sync fields (Section 17): promise-to-pay can be created offline on Android (Section 8.9)
    local_id         UUID,
    device_id        UUID,
    sync_status      sync_status NOT NULL DEFAULT 'SYNCED',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================================================
-- 8. REMINDERS  (Sections 9 & 34)
-- =====================================================================

CREATE TABLE reminder_templates (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  UUID REFERENCES businesses(id) ON DELETE CASCADE,  -- NULL = system default
    language     CHAR(2) NOT NULL DEFAULT 'bn',                     -- 'bn' | 'en'
    channel      reminder_channel NOT NULL DEFAULT 'sms',
    name         TEXT,
    body         TEXT NOT NULL,        -- variables: {customer_name},{balance},{due_amount},{due_date},{business_name}
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE reminder_logs (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id      UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_id      UUID NOT NULL REFERENCES customers(id),
    template_id      UUID REFERENCES reminder_templates(id),
    channel          reminder_channel NOT NULL,
    to_number        VARCHAR(20) NOT NULL,
    message_snapshot TEXT NOT NULL,       -- resolved message actually sent
    status           reminder_status NOT NULL DEFAULT 'queued',
    provider_ref     TEXT,                -- gateway message id
    cost             NUMERIC(10,4),       -- per-message cost (Section 34)
    error            TEXT,
    sent_by          UUID REFERENCES users(id),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    delivered_at     TIMESTAMPTZ
);

-- =====================================================================
-- 9. DEVICES, SYNC, AUDIT  (Sections 17 & 22)
-- =====================================================================

CREATE TABLE devices (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id        UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id            UUID NOT NULL REFERENCES users(id),
    device_identifier  TEXT NOT NULL,
    platform           TEXT,             -- 'android' | 'web'
    last_sync_at       TIMESTAMPTZ,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, device_identifier)
);

CREATE TABLE sync_logs (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    device_id    UUID REFERENCES devices(id),
    user_id      UUID REFERENCES users(id),
    entity       TEXT NOT NULL,          -- 'transaction' | 'customer' | ...
    local_id     UUID,
    server_id    UUID,
    sync_status  sync_status NOT NULL,
    error        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE audit_logs (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id  UUID REFERENCES businesses(id) ON DELETE CASCADE,
    user_id      UUID REFERENCES users(id),
    action       TEXT NOT NULL,          -- 'create'|'update'|'reverse'|'login'|...
    entity       TEXT NOT NULL,
    entity_id    UUID,
    before_data  JSONB,
    after_data   JSONB,
    ip_address   INET,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE audit_logs IS 'Section 15/22. Records who changed sensitive/financial data.';

-- =====================================================================
-- 10. SUBSCRIPTIONS  (Section 24)
-- =====================================================================

CREATE TABLE subscriptions (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id        UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    plan_id            UUID NOT NULL REFERENCES plans(id),
    status             subscription_status NOT NULL DEFAULT 'trialing',
    started_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    current_period_end TIMESTAMPTZ,
    cancelled_at       TIMESTAMPTZ,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================================================
-- 11. INDEXES  (Section 23 — business_id, customer_id, dates, common filters)
-- =====================================================================
CREATE INDEX idx_business_users_user        ON business_users (user_id);
CREATE INDEX idx_customers_business_active  ON customers (business_id, is_active);
CREATE INDEX idx_customers_business_phone   ON customers (business_id, phone);
CREATE INDEX idx_customers_sales_rep        ON customers (assigned_sales_rep_id);
CREATE INDEX idx_txn_business_customer_date ON transactions (business_id, customer_id, transaction_date);
CREATE INDEX idx_txn_business_due           ON transactions (business_id, due_date);
CREATE INDEX idx_txn_business_type          ON transactions (business_id, transaction_type_code);
CREATE INDEX idx_txn_sync                   ON transactions (sync_status) WHERE sync_status <> 'SYNCED';
CREATE INDEX idx_collect_business_customer  ON collection_activities (business_id, customer_id);
CREATE INDEX idx_collect_followup           ON collection_activities (business_id, next_follow_up_at);
CREATE INDEX idx_promise_business_status    ON promise_to_pay (business_id, status);
CREATE INDEX idx_promise_followup           ON promise_to_pay (business_id, follow_up_date);
CREATE INDEX idx_reminder_logs_customer     ON reminder_logs (business_id, customer_id);
CREATE INDEX idx_audit_business_entity      ON audit_logs (business_id, entity, entity_id);
CREATE INDEX idx_sync_logs_business         ON sync_logs (business_id, sync_status);
CREATE INDEX idx_alloc_credit               ON payment_allocations (credit_txn_id);
CREATE INDEX idx_alloc_payment              ON payment_allocations (payment_txn_id);
CREATE INDEX idx_alloc_business             ON payment_allocations (business_id);
CREATE INDEX idx_promise_sync               ON promise_to_pay (sync_status) WHERE sync_status <> 'SYNCED';

-- =====================================================================
-- 12. VIEWS  (balances are COMPUTED, never stored — Section 15)
-- =====================================================================

-- Per-customer running balance. Positive = customer owes the business.
CREATE VIEW customer_balances AS
SELECT
    c.id                                   AS customer_id,
    c.business_id,
    c.name,
    COALESCE(SUM(t.amount * tt.balance_sign), 0)                          AS balance,
    COALESCE(SUM(t.amount) FILTER (WHERE tt.code = 'credit'), 0)          AS total_credit,
    COALESCE(SUM(t.amount) FILTER (WHERE tt.code = 'payment'), 0)         AS total_paid,
    MIN(t.due_date) FILTER (WHERE tt.balance_sign = 1)                    AS oldest_due_date
FROM customers c
LEFT JOIN transactions t       ON t.customer_id = c.id
LEFT JOIN transaction_types tt ON tt.code = t.transaction_type_code
GROUP BY c.id, c.business_id, c.name;
COMMENT ON VIEW customer_balances IS 'Single source of truth for balances (Section 15).';

-- Aging buckets per customer (Section 10). Ages the UNPAID portion of each credit
-- (credit amount − payment_allocations), bucketed by days overdue in the business's
-- OWN timezone (not the server's). Payments must be allocated to credits (FIFO by
-- due_date, by the app at payment time) for these buckets to reconcile with the balance.
CREATE VIEW customer_aging AS
WITH credit_outstanding AS (
    SELECT
        t.business_id,
        t.customer_id,
        t.due_date,
        t.amount - COALESCE(a.allocated, 0) AS outstanding
    FROM transactions t
    JOIN transaction_types tt ON tt.code = t.transaction_type_code
    LEFT JOIN (
        SELECT credit_txn_id, SUM(amount) AS allocated
        FROM payment_allocations
        GROUP BY credit_txn_id
    ) a ON a.credit_txn_id = t.id
    WHERE tt.balance_sign = 1        -- credit + adjustment_debit
      AND t.due_date IS NOT NULL
      AND t.reversal_of_transaction_id IS NULL                        -- exclude reversal entries
      AND NOT EXISTS (SELECT 1 FROM transactions r                     -- exclude reversed credits
                       WHERE r.reversal_of_transaction_id = t.id)
)
SELECT
    co.business_id,
    co.customer_id,
    SUM(co.outstanding) FILTER (WHERE (b.today - co.due_date) BETWEEN 0 AND 7)   AS bucket_0_7,
    SUM(co.outstanding) FILTER (WHERE (b.today - co.due_date) BETWEEN 8 AND 30)  AS bucket_8_30,
    SUM(co.outstanding) FILTER (WHERE (b.today - co.due_date) BETWEEN 31 AND 60) AS bucket_31_60,
    SUM(co.outstanding) FILTER (WHERE (b.today - co.due_date) BETWEEN 61 AND 90) AS bucket_61_90,
    SUM(co.outstanding) FILTER (WHERE (b.today - co.due_date) > 90)              AS bucket_90_plus
FROM credit_outstanding co
JOIN LATERAL (
    SELECT (now() AT TIME ZONE bz.timezone)::date AS today
    FROM businesses bz
    WHERE bz.id = co.business_id
) b ON TRUE
WHERE co.outstanding > 0
GROUP BY co.business_id, co.customer_id;

-- =====================================================================
-- 13. TRIGGERS
-- =====================================================================

-- 13a. Auto-maintain updated_at
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated       BEFORE UPDATE ON users        FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_businesses_updated  BEFORE UPDATE ON businesses   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_customers_updated   BEFORE UPDATE ON customers    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_promise_updated     BEFORE UPDATE ON promise_to_pay FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 13b. Enforce append-only ledger (Section 15): block DELETE, and block edits to
--      financial fields. Only sync bookkeeping fields may change after insert.
CREATE OR REPLACE FUNCTION guard_transactions() RETURNS trigger AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        RAISE EXCEPTION 'transactions are append-only: use a reversal/adjustment row instead of DELETE';
    END IF;
    IF (NEW.amount <> OLD.amount
        OR NEW.transaction_type_code <> OLD.transaction_type_code
        OR NEW.customer_id <> OLD.customer_id
        OR NEW.business_id <> OLD.business_id) THEN
        RAISE EXCEPTION 'financial fields of a transaction are immutable; post a reversal/adjustment instead';
    END IF;
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_txn_guard
    BEFORE UPDATE OR DELETE ON transactions
    FOR EACH ROW EXECUTE FUNCTION guard_transactions();

-- =====================================================================
-- 13c. PAYMENT ALLOCATION (FIFO)  — added 2026-09-07 (review fix H1 / open item O1)
-- =====================================================================
-- Deterministically (re)applies a customer's reducing txns (payment, adjustment_credit)
-- to their outstanding increasing txns (credit, adjustment_debit), OLDEST DUE FIRST,
-- writing payment_allocations so customer_aging reflects UNPAID credit.
--   · Balances never depend on this (balance = Σ amount × balance_sign); allocation is
--     aging attribution only.
--   · Idempotent: clears and recomputes the customer's allocations on every call.
--   · Reversed txns and reversal entries are excluded, so reversing a credit drops it
--     from aging and frees its payments onto the next-oldest credits automatically.
--   · Leftover payment (no outstanding credit left) stays UNALLOCATED = advance/overpayment.
-- Call inside the same DB transaction as any payment / credit / reversal insert:
--     SELECT reallocate_customer(:business_id, :customer_id);
CREATE OR REPLACE FUNCTION reallocate_customer(p_business_id UUID, p_customer_id UUID)
RETURNS void AS $$
DECLARE
    rec_pay    RECORD;
    rec_credit RECORD;
    v_left     NUMERIC(14,2);
    v_take     NUMERIC(14,2);
BEGIN
    -- serialize allocation per customer so concurrent payments can't double-allocate
    PERFORM pg_advisory_xact_lock(hashtext(p_customer_id::text)::bigint);

    -- start clean for this customer
    DELETE FROM payment_allocations
     WHERE business_id = p_business_id
       AND credit_txn_id IN (SELECT id FROM transactions
                             WHERE business_id = p_business_id AND customer_id = p_customer_id);

    -- outstanding increasing txns (active only), oldest-due first, with a working remaining
    DROP TABLE IF EXISTS _inc;
    CREATE TEMP TABLE _inc AS
      SELECT row_number() OVER (ORDER BY t.due_date NULLS LAST, t.created_at, t.id) AS ord,
             t.id, t.amount AS remaining
        FROM transactions t
        JOIN transaction_types tt ON tt.code = t.transaction_type_code
       WHERE t.business_id = p_business_id AND t.customer_id = p_customer_id
         AND tt.balance_sign = 1
         AND t.reversal_of_transaction_id IS NULL
         AND NOT EXISTS (SELECT 1 FROM transactions r WHERE r.reversal_of_transaction_id = t.id);

    -- walk reducing txns (active only), oldest-first, applying each across outstanding credits
    FOR rec_pay IN
        SELECT t.id, t.amount
          FROM transactions t
          JOIN transaction_types tt ON tt.code = t.transaction_type_code
         WHERE t.business_id = p_business_id AND t.customer_id = p_customer_id
           AND tt.balance_sign = -1
           AND t.reversal_of_transaction_id IS NULL
           AND NOT EXISTS (SELECT 1 FROM transactions r WHERE r.reversal_of_transaction_id = t.id)
         ORDER BY t.created_at, t.id
    LOOP
        v_left := rec_pay.amount;
        FOR rec_credit IN SELECT id, remaining FROM _inc WHERE remaining > 0 ORDER BY ord LOOP
            EXIT WHEN v_left <= 0;
            v_take := least(v_left, rec_credit.remaining);
            INSERT INTO payment_allocations (business_id, payment_txn_id, credit_txn_id, amount)
                 VALUES (p_business_id, rec_pay.id, rec_credit.id, v_take);
            UPDATE _inc SET remaining = remaining - v_take WHERE id = rec_credit.id;
            v_left := v_left - v_take;
        END LOOP;
        -- v_left > 0 here => unapplied advance / overpayment (intentionally left unallocated)
    END LOOP;

    DROP TABLE IF EXISTS _inc;
END;
$$ LANGUAGE plpgsql;
COMMENT ON FUNCTION reallocate_customer(UUID, UUID) IS
  'FIFO payment→credit allocation for aging. Idempotent; call after any payment/credit/reversal.';

-- =====================================================================
-- 14. ROW-LEVEL SECURITY  (defense-in-depth for Section 5 tenant isolation)
--     App sets:  SET app.current_business_id = '<uuid>';  per request/connection.
--     Policies then make it impossible to read/write another business's rows,
--     even if an application query forgets its WHERE business_id filter.
-- =====================================================================
-- IMPORTANT: RLS is NOT enforced for a table's OWNER unless FORCE is set, and is
-- bypassed by any role with BYPASSRLS. Run migrations as the owner, but have the
-- APPLICATION connect as a dedicated, non-owner role WITHOUT BYPASSRLS, e.g.:
--     CREATE ROLE bakibondhu_app LOGIN PASSWORD '...';
--     GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO bakibondhu_app;
-- FORCE ROW LEVEL SECURITY below is belt-and-suspenders so the policy also binds the owner.
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
     'customers','customer_contacts','sales_representatives','customer_assignments',
     'transactions','payment_allocations','collection_activities','promise_to_pay',
     'reminder_templates','reminder_logs','devices','sync_logs','audit_logs','subscriptions'
  ] LOOP
     EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
     EXECUTE format('ALTER TABLE %I FORCE  ROW LEVEL SECURITY;', t);
     EXECUTE format($f$
        CREATE POLICY tenant_isolation ON %I
        USING (business_id = NULLIF(current_setting('app.current_business_id', true), '')::uuid)
        WITH CHECK (business_id = NULLIF(current_setting('app.current_business_id', true), '')::uuid);
     $f$, t);
  END LOOP;
END $$;

-- business_users is the MEMBERSHIP LOOKUP table and must NOT use plain tenant
-- isolation: at login the server lists a user's businesses BEFORE any business is
-- selected (app.current_business_id is still unset), so a business_id-only policy
-- would return zero rows and break multi-business login. Scope it by user instead,
-- while still letting owners/managers see members of the ACTIVE business.
-- The app sets:  SET app.current_user_id = '<uuid>';  at authentication time.
ALTER TABLE business_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_users FORCE  ROW LEVEL SECURITY;
CREATE POLICY membership_visibility ON business_users
    USING (
        user_id     = NULLIF(current_setting('app.current_user_id',     true), '')::uuid
     OR business_id = NULLIF(current_setting('app.current_business_id', true), '')::uuid
    )
    WITH CHECK (business_id = NULLIF(current_setting('app.current_business_id', true), '')::uuid);

-- NOTE: reminder_templates.business_id is NULL for system defaults; the tenant
-- policy above hides them. Add a permissive read policy for shared templates:
--   CREATE POLICY system_templates_readable ON reminder_templates
--     FOR SELECT USING (business_id IS NULL);

-- =====================================================================
-- 15. SEED DATA
-- =====================================================================
-- Directional types keep  balance = Σ(amount × balance_sign)  correct for every
-- entry, including corrections. A reversal is posted as the opposite-direction
-- adjustment with reversal_of_transaction_id set (never by editing the original).
INSERT INTO transaction_types (code, name, balance_sign) VALUES
    ('credit',            'Credit sale (baki given)',                    1),
    ('payment',           'Payment received',                           -1),
    ('adjustment_debit',  'Adjustment — increase receivable',            1),
    ('adjustment_credit', 'Adjustment / reversal — decrease receivable', -1);

INSERT INTO roles (code, name, is_system) VALUES
    ('owner',             'Business Owner',       TRUE),
    ('manager',           'Manager',              TRUE),
    ('sales_rep',         'Sales Representative',  TRUE),
    ('collection_officer','Collection Officer',    TRUE),
    ('sysadmin',          'System Administrator',  TRUE);

INSERT INTO plans (code, name, price_monthly, limits, features) VALUES
    ('free',     'Free',        0,    '{"max_users":1}',    '{"reminders":"manual","reports":"basic"}'),
    ('pro',      'Pro',         249,  '{"max_users":3}',    '{"reminders":"scheduled","aging":true,"reports":"rich"}'),
    ('business', 'Business',    1499, '{"max_users":null}', '{"staff":true,"territories":true,"analytics":true}');

-- Default Bangla reminder template (business_id NULL = system default)
INSERT INTO reminder_templates (business_id, language, channel, name, body) VALUES
    (NULL, 'bn', 'sms', 'Polite due reminder',
     'আসসালামু আলাইকুম {customer_name} ভাই। আপনার কাছে {business_name}-এ ৳{balance} বাকি আছে। সুবিধামতো পরিশোধ করলে উপকৃত হতাম। ধন্যবাদ।');

-- =====================================================================
-- END OF SCHEMA
-- =====================================================================
```
