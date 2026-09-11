-- BakiBondhu PHP backend — MySQL schema (auth: businesses + users).
-- Import this in cPanel → phpMyAdmin → your database → Import.
-- Charset utf8mb4 so Bangla names store correctly.

CREATE TABLE IF NOT EXISTS businesses (
    id         CHAR(36)     NOT NULL,
    name       VARCHAR(200) NOT NULL,
    timezone   VARCHAR(64)  NOT NULL DEFAULT 'Asia/Dhaka',
    currency   VARCHAR(8)   NOT NULL DEFAULT 'BDT',
    created_at DATETIME     NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
    created_at  VARCHAR(64)  NOT NULL,
    updated_at  DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_cust_idem (business_id, device_id, local_id),
    KEY idx_cust_business_updated (business_id, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
