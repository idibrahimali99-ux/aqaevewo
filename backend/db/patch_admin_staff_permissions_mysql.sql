-- Add optional permissions for staff accounts in the admin app.
-- Safe to run multiple times.
SET NAMES utf8mb4;

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'staff_permissions_json'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE users ADD COLUMN staff_permissions_json JSON NULL AFTER created_by',
  'SELECT 1');
PREPARE _vewo_staff_perm FROM @sql; EXECUTE _vewo_staff_perm; DEALLOCATE PREPARE _vewo_staff_perm;
