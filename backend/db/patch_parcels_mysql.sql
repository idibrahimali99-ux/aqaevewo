-- إنشاء جدول المقاطعات + ربط العقارات بالمقاطعة (للمنشورات بنمط parcel)
USE vewo;

CREATE TABLE IF NOT EXISTS parcels (
  id CHAR(36) NOT NULL,
  governorate VARCHAR(100) NOT NULL,
  district_id CHAR(36) NULL,
  parcel_name VARCHAR(255) NOT NULL,
  parcel_no VARCHAR(40) NOT NULL DEFAULT '',
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  follower_count INT NOT NULL DEFAULT 0,
  synthetic_follower_boost INT NOT NULL DEFAULT 0,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_parcels_unique (governorate, parcel_name, parcel_no),
  KEY idx_parcels_active_sort (is_active, sort_order, created_at),
  KEY idx_parcels_district (district_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

SET @c = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'parcels' AND column_name = 'follower_count');
SET @sql = IF(@c = 0,
  'ALTER TABLE parcels ADD COLUMN follower_count INT NOT NULL DEFAULT 0',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'parcels' AND column_name = 'synthetic_follower_boost');
SET @sql = IF(@c = 0,
  'ALTER TABLE parcels ADD COLUMN synthetic_follower_boost INT NOT NULL DEFAULT 0 AFTER follower_count',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'parcel_id');
SET @sql = IF(@c = 0,
  'ALTER TABLE properties ADD COLUMN parcel_id CHAR(36) NULL AFTER owner_user_id',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @idx = (SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'properties' AND index_name = 'idx_properties_parcel');
SET @sql = IF(@idx = 0,
  'ALTER TABLE properties ADD INDEX idx_properties_parcel (parcel_id)',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- FK (قد يفشل إذا كانت موجودة مسبقاً أو إن كان محرك/ترميز مختلف). نفّذه يدوياً عند الحاجة.
