-- ============================================================================
-- ضمان جدول districts + عمود kind (أقضية ونواحي — ذي قار وجميع المحافظات)
-- تشغيل مرة واحدة على قاعدة vewo
--
-- لا نضيف FOREIGN KEY هنا: Errno 150 يظهر عند اختلاف COLLATE/CHARSET بين
-- governorate_id و governorates.id (جداول قديمة بترميزات مختلفة). الفهرس
-- idx_districts_gov كافٍ للأداء؛ الربط يضبطه التطبيق.
-- لإضافة قيد FK اختياري لاحقاً: patch_districts_foreign_key_optional_mysql.sql
-- ============================================================================

USE vewo;

CREATE TABLE IF NOT EXISTS `districts` (
  `id` CHAR(36) NOT NULL,
  `governorate_id` CHAR(36) NOT NULL,
  `name` VARCHAR(160) NOT NULL,
  `kind` VARCHAR(16) NOT NULL DEFAULT 'qada',
  `sort_order` INT NOT NULL DEFAULT 0,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_districts_gov` (`governorate_id`, `is_active`, `sort_order`, `name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- جداول قديمة أُنشئت بدون عمود kind
SET @dc_sql := (
  SELECT IF(
    (
      SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'districts'
        AND COLUMN_NAME = 'kind'
    ) > 0,
    'SELECT 1',
    'ALTER TABLE `districts` ADD COLUMN `kind` VARCHAR(16) NOT NULL DEFAULT ''qada'' AFTER `name`'
  )
);
PREPARE _dc_stmt FROM @dc_sql;
EXECUTE _dc_stmt;
DEALLOCATE PREPARE _dc_stmt;
