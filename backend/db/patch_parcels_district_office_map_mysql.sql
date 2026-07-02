-- تشغيل بعد patch_users_profile_marketer_districts_mysql.sql (جدول governorates + districts)
USE vewo;

-- موقع المكتب على الخريطة (تسجيل مكتب / مسوّق)
SET @c = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_lat');
SET @sql = IF(@c = 0,
  'ALTER TABLE users ADD COLUMN office_lat DOUBLE NULL DEFAULT NULL AFTER office_address',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_lng');
SET @sql = IF(@c = 0,
  'ALTER TABLE users ADD COLUMN office_lng DOUBLE NULL DEFAULT NULL AFTER office_lat',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ربط المقاطعة بقضاء/ناحية (اختياري للصفوف القديمة)
SET @c = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'parcels' AND column_name = 'district_id');
SET @sql = IF(@c = 0,
  'ALTER TABLE parcels ADD COLUMN district_id CHAR(36) NULL AFTER governorate',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @idx = (SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'parcels' AND index_name = 'idx_parcels_district');
SET @sql = IF(@idx = 0,
  'ALTER TABLE parcels ADD INDEX idx_parcels_district (district_id)',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
