-- Helium Reader MySQL schema
-- Stores per-user, per-book reading progress keyed by Google Drive fileId.

CREATE TABLE IF NOT EXISTS book_progress (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_email VARCHAR(320) NOT NULL,
  drive_file_id VARCHAR(191) NOT NULL,
  cfi TEXT NULL,
  chapter INT NULL,
  percent DECIMAL(6,3) NULL,
  updated_at_ms BIGINT NOT NULL,
  device_name VARCHAR(120) NOT NULL,
  updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
    ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_file (user_email, drive_file_id),
  KEY idx_user_updated (user_email, updated_at_ms)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
