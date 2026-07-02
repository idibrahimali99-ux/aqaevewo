-- =============================================================================
-- MariaDB / MySQL — purpose + details_json (آمن عند إعادة التشغيل)
--
-- لا يعيد إضافة عمود إن وُجد مسبقاً (#1060 Duplicate column).
-- =============================================================================

USE vewo;

SET NAMES utf8mb4;

-- عمود purpose
SET @c := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'properties'
    AND COLUMN_NAME = 'purpose'
);
SET @sql := IF(
  @c = 0,
  'ALTER TABLE properties ADD COLUMN purpose VARCHAR(20) NOT NULL DEFAULT ''sale'' AFTER category',
  'SELECT 1'
);
PREPARE _vewo_p FROM @sql;
EXECUTE _vewo_p;
DEALLOCATE PREPARE _vewo_p;

-- عمود details_json
SET @c := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'properties'
    AND COLUMN_NAME = 'details_json'
);
SET @sql := IF(
  @c = 0,
  'ALTER TABLE properties ADD COLUMN details_json LONGTEXT NULL AFTER description',
  'SELECT 1'
);
PREPARE _vewo_p FROM @sql;
EXECUTE _vewo_p;
DEALLOCATE PREPARE _vewo_p;

-- قيد CHECK (إن لم يكن موجوداً)
SET @c := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE CONSTRAINT_SCHEMA = DATABASE()
    AND TABLE_NAME = 'properties'
    AND CONSTRAINT_NAME = 'chk_properties_purpose'
);
SET @sql := IF(
  @c = 0,
  'ALTER TABLE properties ADD CONSTRAINT chk_properties_purpose CHECK (purpose IN (''sale'', ''rent''))',
  'SELECT 1'
);
PREPARE _vewo_p FROM @sql;
EXECUTE _vewo_p;
DEALLOCATE PREPARE _vewo_p;
