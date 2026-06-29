-- 187Cleaner — Database Schema
-- Run this SQL before starting the resource

CREATE TABLE IF NOT EXISTS `187cleaner_players` (
    `identifier`         VARCHAR(60)    NOT NULL PRIMARY KEY,
    `cleaner_rep`        INT            NOT NULL DEFAULT 0,
    `broker_rep`         INT            NOT NULL DEFAULT 0,
    `kit_tier`           TINYINT        NOT NULL DEFAULT 0,
    `total_contracts`    INT            NOT NULL DEFAULT 0,
    `total_earned`       INT            NOT NULL DEFAULT 0,
    `total_bodies`       INT            NOT NULL DEFAULT 0,
    `evidence_destroyed` INT            NOT NULL DEFAULT 0,
    `betrayals`          INT            NOT NULL DEFAULT 0,
    `fastest_clean`      INT            NOT NULL DEFAULT 0  COMMENT 'seconds',
    `current_streak`     INT            NOT NULL DEFAULT 0  COMMENT 'consecutive clean contracts (no evidence pocketed)',
    `best_streak`        INT            NOT NULL DEFAULT 0,
    `created_at`         TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `187cleaner_evidence` (
    `id`             INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `identifier`     VARCHAR(60)  NOT NULL,
    `evidence_type`  VARCHAR(40)  NOT NULL,
    `evidence_value` INT          NOT NULL DEFAULT 0,
    `contract_tier`  TINYINT      NOT NULL DEFAULT 1,
    `created_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
