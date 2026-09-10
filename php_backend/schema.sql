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
