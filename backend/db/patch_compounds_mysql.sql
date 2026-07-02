-- مجمعات سكنية (إدارة من لوحة الأدمن) + ربط المنشورات category=compound
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS compounds (
  id CHAR(36) NOT NULL,
  governorate VARCHAR(100) NOT NULL,
  district_id CHAR(36) NULL,
  district_name VARCHAR(160) NOT NULL DEFAULT '',
  compound_name VARCHAR(255) NOT NULL,
  photo_url VARCHAR(1000) NOT NULL DEFAULT '',
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  follower_count INT NOT NULL DEFAULT 0,
  synthetic_follower_boost INT NOT NULL DEFAULT 0,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_compounds_gov_name (governorate, compound_name),
  KEY idx_compounds_active_sort (is_active, sort_order, compound_name),
  KEY idx_compounds_district (district_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @c := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'compounds' AND column_name = 'district_id'
);
SET @sql := IF(@c = 0,
  'ALTER TABLE compounds ADD COLUMN district_id CHAR(36) NULL AFTER governorate',
  'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @c := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'compounds' AND column_name = 'district_name'
);
SET @sql := IF(@c = 0,
  'ALTER TABLE compounds ADD COLUMN district_name VARCHAR(160) NOT NULL DEFAULT '''' AFTER district_id',
  'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx := (
  SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'compounds' AND index_name = 'idx_compounds_district'
);
SET @sql := IF(@idx = 0,
  'ALTER TABLE compounds ADD INDEX idx_compounds_district (district_id)',
  'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @c := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'compounds' AND column_name = 'follower_count'
);
SET @sql := IF(@c = 0,
  'ALTER TABLE compounds ADD COLUMN follower_count INT NOT NULL DEFAULT 0',
  'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @c := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'compounds' AND column_name = 'synthetic_follower_boost'
);
SET @sql := IF(@c = 0,
  'ALTER TABLE compounds ADD COLUMN synthetic_follower_boost INT NOT NULL DEFAULT 0 AFTER follower_count',
  'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_col := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'compound_id'
);
SET @has_parcel_col := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'parcel_id'
);
SET @sql := IF(@has_col = 0,
  IF(@has_parcel_col > 0,
    'ALTER TABLE properties ADD COLUMN compound_id CHAR(36) NULL AFTER parcel_id',
    'ALTER TABLE properties ADD COLUMN compound_id CHAR(36) NULL AFTER owner_user_id'
  ),
  'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @fk := (
  SELECT COUNT(*) FROM information_schema.table_constraints
  WHERE table_schema = DATABASE() AND table_name = 'properties'
    AND constraint_name = 'fk_properties_compound'
);
SET @sql2 := IF(@fk = 0,
  'ALTER TABLE properties ADD CONSTRAINT fk_properties_compound FOREIGN KEY (compound_id) REFERENCES compounds(id) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1');
PREPARE stmt2 FROM @sql2;
EXECUTE stmt2;
DEALLOCATE PREPARE stmt2;

SET @idx := (
  SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'properties' AND index_name = 'idx_properties_compound'
);
SET @sql3 := IF(@idx = 0,
  'ALTER TABLE properties ADD INDEX idx_properties_compound (compound_id)',
  'SELECT 1');
PREPARE stmt3 FROM @sql3;
EXECUTE stmt3;
DEALLOCATE PREPARE stmt3;
