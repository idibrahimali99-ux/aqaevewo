-- تشغيل آمن أكثر من مرة: يتخطى الأعمدة إذا كانت موجودة (لا خطأ 1060).
-- قاعدة: vewo

USE vewo;

-- ---------------------------------------------------------------------------
-- أعمدة users: profile_photo_url ، is_marketer
-- ---------------------------------------------------------------------------
SET @_sql := (
  SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'profile_photo_url') > 0,
    'SELECT 1',
    'ALTER TABLE `users` ADD COLUMN `profile_photo_url` VARCHAR(1000) NOT NULL DEFAULT '''' AFTER `office_photo_url`'
  )
);
PREPARE _stmt_users_photo FROM @_sql;
EXECUTE _stmt_users_photo;
DEALLOCATE PREPARE _stmt_users_photo;

SET @_sql := (
  SELECT IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'is_marketer') > 0,
    'SELECT 1',
    'ALTER TABLE `users` ADD COLUMN `is_marketer` TINYINT(1) NOT NULL DEFAULT 0 AFTER `office_verified`'
  )
);
PREPARE _stmt_users_mk FROM @_sql;
EXECUTE _stmt_users_mk;
DEALLOCATE PREPARE _stmt_users_mk;

-- ---------------------------------------------------------------------------
-- districts (بدون FOREIGN KEY — يتجنب errno 150 عند اختلاف COLLATE مع governorates)
-- للجدول الكامل انظر أيضاً: patch_districts_ensure_mysql.sql
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS districts (
  id CHAR(36) NOT NULL,
  governorate_id CHAR(36) NOT NULL,
  name VARCHAR(160) NOT NULL,
  kind VARCHAR(16) NOT NULL DEFAULT 'qada',
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_districts_gov (governorate_id, is_active, sort_order, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
