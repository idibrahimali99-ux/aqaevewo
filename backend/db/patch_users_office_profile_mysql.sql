-- حقول إضافية لحساب المكتب عند التسجيل (عنوان، إجازة، صورة)
SET @c = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_address');
SET @sql = IF(@c = 0,
  'ALTER TABLE users ADD COLUMN office_address VARCHAR(500) NOT NULL DEFAULT \'\' AFTER phone',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_license_no');
SET @sql = IF(@c = 0,
  'ALTER TABLE users ADD COLUMN office_license_no VARCHAR(120) NOT NULL DEFAULT \'\' AFTER office_address',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_photo_url');
SET @sql = IF(@c = 0,
  'ALTER TABLE users ADD COLUMN office_photo_url VARCHAR(1000) NOT NULL DEFAULT \'\' AFTER office_license_no',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
