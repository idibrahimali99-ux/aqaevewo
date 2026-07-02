-- Add optional email login for users.
-- Safe to run multiple times.
SET NAMES utf8mb4;

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'email'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE users ADD COLUMN email VARCHAR(255) NULL AFTER phone',
  'SELECT 1');
PREPARE _vewo_users_email FROM @sql; EXECUTE _vewo_users_email; DEALLOCATE PREPARE _vewo_users_email;

SET @idx_exists = (
  SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'users' AND index_name = 'uq_users_email'
);
SET @sql = IF(@idx_exists = 0,
  'ALTER TABLE users ADD UNIQUE KEY uq_users_email (email)',
  'SELECT 1');
PREPARE _vewo_users_email_idx FROM @sql; EXECUTE _vewo_users_email_idx; DEALLOCATE PREPARE _vewo_users_email_idx;
