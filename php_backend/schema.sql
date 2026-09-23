-- BakiBondhu PHP backend — MySQL schema (auth: businesses + users).
-- Import this in cPanel → phpMyAdmin → your database → Import.
-- Charset utf8mb4 so Bangla names store correctly.

CREATE TABLE IF NOT EXISTS businesses (
    id         CHAR(36)     NOT NULL,
    name       VARCHAR(200) NOT NULL,
    timezone   VARCHAR(64)  NOT NULL DEFAULT 'Asia/Dhaka',
    currency   VARCHAR(8)   NOT NULL DEFAULT 'BDT',
    status     VARCHAR(16)  NOT NULL DEFAULT 'active',  -- active|suspended (admin panel)
    country    VARCHAR(64)  NULL DEFAULT 'Bangladesh',  -- shop country (from registration)
    thana      VARCHAR(100) NULL,   -- shop location (optional, from registration; BD: thana, else: city)
    zila       VARCHAR(100) NULL,   -- BD: district; other countries: state/province
    expires_at DATE         NULL,   -- subscription expiry; NULL = unlimited. New signups get a 30-day trial (BB_TRIAL_DAYS); admin can extend/clear.
    created_at DATETIME     NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- Existing installs: ALTER TABLE businesses ADD COLUMN status VARCHAR(16) NOT NULL DEFAULT 'active';
-- Existing installs: ALTER TABLE businesses ADD COLUMN thana VARCHAR(100) NULL, ADD COLUMN zila VARCHAR(100) NULL;
-- Existing installs: ALTER TABLE businesses ADD COLUMN expires_at DATE NULL;
-- Existing installs: ALTER TABLE businesses ADD COLUMN country VARCHAR(64) NULL DEFAULT 'Bangladesh';

CREATE TABLE IF NOT EXISTS users (
    id            CHAR(36)     NOT NULL,
    business_id   CHAR(36)     NOT NULL,
    name          VARCHAR(200) NOT NULL,
    phone         VARCHAR(32)  NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(32)  NOT NULL DEFAULT 'owner',
    created_at    DATETIME     NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_phone (phone),
    KEY idx_users_business (business_id),
    CONSTRAINT fk_users_business FOREIGN KEY (business_id) REFERENCES businesses (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Synced ledger (offline sync). Each row is idempotent on
-- (business_id, device_id, local_id) so replaying a push never duplicates.
-- `updated_at` is the pull cursor (server assigns UTC_TIMESTAMP(6) on write).
CREATE TABLE IF NOT EXISTS customers (
    id          CHAR(36)     NOT NULL,   -- server id
    business_id CHAR(36)     NOT NULL,
    device_id   VARCHAR(64)  NOT NULL,
    local_id    CHAR(36)     NOT NULL,   -- the client's local uuid
    name        VARCHAR(200) NOT NULL,
    phone       VARCHAR(32)  NULL,
    address     VARCHAR(255) NULL,
    created_at  VARCHAR(64)  NOT NULL,
    updated_at  DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_cust_idem (business_id, device_id, local_id),
    -- Customer mobile numbers are unique within a shop. phone is NULLable and
    -- MySQL allows many NULLs in a unique index, so phone-less customers are ok.
    UNIQUE KEY uq_cust_phone (business_id, phone),
    KEY idx_cust_business_updated (business_id, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- Existing installs: ALTER TABLE customers ADD UNIQUE KEY uq_cust_phone (business_id, phone);

CREATE TABLE IF NOT EXISTS transactions (
    id           CHAR(36)     NOT NULL,   -- server id
    business_id  CHAR(36)     NOT NULL,
    device_id    VARCHAR(64)  NOT NULL,
    local_id     CHAR(36)     NOT NULL,   -- the client's local uuid
    customer_id  CHAR(36)     NOT NULL,   -- server customer id
    type         VARCHAR(32)  NOT NULL,   -- credit|payment|adjustment_debit|adjustment_credit
    amount_paisa BIGINT       NOT NULL,
    due_date     VARCHAR(32)  NULL,
    note         TEXT         NULL,
    created_at   VARCHAR(64)  NOT NULL,
    updated_at   DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_txn_idem (business_id, device_id, local_id),
    KEY idx_txn_business_updated (business_id, updated_at),
    KEY idx_txn_customer (customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Direct sales (owner records each sale's amount; no customer). Daily/monthly/
-- quarterly/yearly totals come from these rows. Same idempotency as the ledger.
CREATE TABLE IF NOT EXISTS sales (
    id           CHAR(36)     NOT NULL,   -- server id (== client local_id)
    business_id  CHAR(36)     NOT NULL,
    device_id    VARCHAR(64)  NOT NULL,
    local_id     CHAR(36)     NOT NULL,
    amount_paisa BIGINT       NOT NULL,
    note         TEXT         NULL,
    sold_at      VARCHAR(64)  NOT NULL,   -- when the sale happened (client, UTC ISO)
    created_at   VARCHAR(64)  NOT NULL,
    updated_at   DATETIME(6)  NOT NULL,   -- pull cursor
    PRIMARY KEY (id),
    UNIQUE KEY uq_sales_idem (business_id, device_id, local_id),
    KEY idx_sales_business_updated (business_id, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Collection activities & promise-to-pay. Shared by the web app AND the Android
-- app via offline sync (device_id/local_id idempotency + updated_at pull cursor,
-- like customers/transactions/sales). Scoped to a business + customer.
CREATE TABLE IF NOT EXISTS collection_activities (
    id             CHAR(36)     NOT NULL,   -- server id (== client local_id)
    business_id    CHAR(36)     NOT NULL,
    device_id      VARCHAR(64)  NOT NULL,   -- 'web' for REST-created rows
    local_id       CHAR(36)     NOT NULL,
    customer_id    CHAR(36)     NOT NULL,
    method         VARCHAR(16)  NOT NULL,   -- phone|visit|message|other
    status         VARCHAR(32)  NOT NULL,   -- contacted|promise_to_pay|paid|…
    note           TEXT         NULL,
    next_follow_up DATE         NULL,
    contacted_at   DATETIME(6)  NOT NULL,
    created_at     DATETIME     NOT NULL,
    updated_at     DATETIME(6)  NOT NULL,   -- pull cursor
    PRIMARY KEY (id),
    UNIQUE KEY uq_collection_activities_idem (business_id, device_id, local_id),
    KEY idx_ca_bc (business_id, customer_id),
    KEY idx_collection_activities_bu (business_id, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS promise_to_pay (
    id             CHAR(36)     NOT NULL,   -- server id (== client local_id)
    business_id    CHAR(36)     NOT NULL,
    device_id      VARCHAR(64)  NOT NULL,   -- 'web' for REST-created rows
    local_id       CHAR(36)     NOT NULL,
    customer_id    CHAR(36)     NOT NULL,
    amount_paisa   BIGINT       NOT NULL,
    promise_date   DATE         NOT NULL,
    follow_up_date DATE         NULL,
    status         VARCHAR(16)  NOT NULL DEFAULT 'open',  -- open|fulfilled|partial|broken
    created_at     DATETIME     NOT NULL,
    updated_at     DATETIME(6)  NOT NULL,   -- pull cursor
    PRIMARY KEY (id),
    UNIQUE KEY uq_promise_to_pay_idem (business_id, device_id, local_id),
    KEY idx_pp_bc (business_id, customer_id),
    KEY idx_promise_to_pay_bu (business_id, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---- Admin panel (super-admin over the whole platform) --------------------

-- Platform admins (separate from per-business users). Password bcrypt-hashed.
CREATE TABLE IF NOT EXISTS admins (
    id            CHAR(36)     NOT NULL,
    username      VARCHAR(64)  NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at    DATETIME     NOT NULL,
    last_login    DATETIME     NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_admins_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Audit trail: every admin action (esp. destructive ones) is recorded.
CREATE TABLE IF NOT EXISTS admin_audit (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    admin_id   CHAR(36)        NOT NULL,
    action     VARCHAR(64)     NOT NULL,   -- e.g. suspend_business, delete_user
    target     VARCHAR(200)    NULL,       -- id/name the action applied to
    detail     TEXT            NULL,
    at         DATETIME(6)     NOT NULL,
    PRIMARY KEY (id),
    KEY idx_audit_at (at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
