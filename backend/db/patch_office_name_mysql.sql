-- اسم المكتب التجاري (منفصل عن اسم ممثل المكتب في full_name)
SET @c = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_name');
SET @sql = IF(@c = 0,
  'ALTER TABLE users ADD COLUMN office_name VARCHAR(255) NOT NULL DEFAULT \'\' AFTER full_name',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
