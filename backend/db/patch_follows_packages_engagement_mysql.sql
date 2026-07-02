-- متابعة (مكتب/مجمع/مقاطعة) + باقات النشر + لايكات تركيبية للمنشورات
-- نفّذ مرة واحدة على قاعدة الإنتاج.

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS vewo_follows (
  id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  target_kind VARCHAR(16) NOT NULL,
  target_id CHAR(36) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_vewo_follow (user_id, target_kind, target_id),
  KEY idx_vewo_follow_target (target_kind, target_id),
  CONSTRAINT chk_vewo_follow_kind CHECK (target_kind IN ('office','compound','parcel'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS posting_packages (
  id CHAR(36) NOT NULL,
  name_ar VARCHAR(120) NOT NULL,
  listing_limit INT NULL DEFAULT NULL COMMENT 'NULL = بلا حدود',
  applies_to VARCHAR(16) NOT NULL DEFAULT 'both',
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_packages_active (is_active, sort_order),
  CONSTRAINT chk_packages_applies CHECK (applies_to IN ('office','marketer','both'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- أعمدة compounds
SET @_c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'compounds' AND column_name = 'district_id');
SET @_sql := IF(@_c = 0,
  'ALTER TABLE compounds ADD COLUMN district_id CHAR(36) NULL AFTER governorate',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @_c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'compounds' AND column_name = 'district_name');
SET @_sql := IF(@_c = 0,
  'ALTER TABLE compounds ADD COLUMN district_name VARCHAR(160) NOT NULL DEFAULT '''' AFTER district_id',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @_c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'compounds' AND column_name = 'follower_count');
SET @_sql := IF(@_c = 0,
  'ALTER TABLE compounds ADD COLUMN follower_count INT NOT NULL DEFAULT 0',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @_c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'compounds' AND column_name = 'synthetic_follower_boost');
SET @_sql := IF(@_c = 0,
  'ALTER TABLE compounds ADD COLUMN synthetic_follower_boost INT NOT NULL DEFAULT 0 AFTER follower_count',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;

-- أعمدة parcels
SET @_c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'parcels' AND column_name = 'follower_count');
SET @_sql := IF(@_c = 0,
  'ALTER TABLE parcels ADD COLUMN follower_count INT NOT NULL DEFAULT 0',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @_c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'parcels' AND column_name = 'synthetic_follower_boost');
SET @_sql := IF(@_c = 0,
  'ALTER TABLE parcels ADD COLUMN synthetic_follower_boost INT NOT NULL DEFAULT 0 AFTER follower_count',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;

-- مكاتب/مسوقين: متابعون
SET @_c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'follower_count');
SET @_sql := IF(@_c = 0,
  'ALTER TABLE users ADD COLUMN follower_count INT NOT NULL DEFAULT 0',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @_c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'synthetic_follower_boost');
SET @_sql := IF(@_c = 0,
  'ALTER TABLE users ADD COLUMN synthetic_follower_boost INT NOT NULL DEFAULT 0 AFTER follower_count',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @_c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'posting_package_id');
SET @_sql := IF(@_c = 0,
  'ALTER TABLE users ADD COLUMN posting_package_id CHAR(36) NULL AFTER posting_listings_remaining',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;

-- لايكات تركيبية للمنشورات (جدولة الإدارة)
SET @_c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'synthetic_likes');
SET @_sql := IF(@_c = 0,
  'ALTER TABLE properties ADD COLUMN synthetic_likes INT NOT NULL DEFAULT 0 AFTER views',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;

INSERT INTO posting_packages (id, name_ar, listing_limit, applies_to, sort_order, is_active)
SELECT UUID(), 'تجريبي — بلا حدود', NULL, 'both', 0, 1
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM posting_packages LIMIT 1);

-- فترات منفصلة للمشاهدات واللايكات في الجدولة
SET @_c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'admin_engagement_rules' AND column_name = 'views_interval_seconds');
SET @_sql := IF(@_c = 0,
  'ALTER TABLE admin_engagement_rules ADD COLUMN views_interval_seconds INT NULL AFTER interval_seconds',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @_c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'admin_engagement_rules' AND column_name = 'likes_interval_seconds');
SET @_sql := IF(@_c = 0,
  'ALTER TABLE admin_engagement_rules ADD COLUMN likes_interval_seconds INT NULL AFTER views_interval_seconds',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;
