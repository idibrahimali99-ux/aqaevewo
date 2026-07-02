-- رقم عرض للمنشور (#20000001 …) للبحث والنسخ
SET NAMES utf8mb4;
USE vewo;

SET @col = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'property_public_no');
SET @sql = IF(@col = 0,
  'ALTER TABLE properties ADD COLUMN property_public_no INT UNSIGNED NULL UNIQUE COMMENT ''رقم يظهر للمستخدم'' AFTER id',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @n = 20000000;
UPDATE properties
  SET property_public_no = (@n := @n + 1)
  WHERE property_public_no IS NULL
  ORDER BY created_at ASC;
