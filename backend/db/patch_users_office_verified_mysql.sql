-- علامة توثيق بجانب اسم المكتب (مثل «مُوثّق»)
SET NAMES utf8mb4;
USE vewo;

SET @col = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_verified');
SET @sql = IF(@col = 0,
  'ALTER TABLE users ADD COLUMN office_verified TINYINT(1) NOT NULL DEFAULT 0 AFTER office_approved',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
