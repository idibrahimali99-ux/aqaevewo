-- =============================================================================
-- اختياري — فقط إذا كان جدول properties بدون عمود segment
-- (التطبيق الحالي يستخدم segment في الإنشاء والعرض)
--
-- نفّذ مرة واحدة. إن ظهر Duplicate column name فلا حاجة لهذا الملف.
-- =============================================================================

USE vewo;

SET NAMES utf8mb4;

ALTER TABLE properties
  ADD COLUMN segment VARCHAR(20) NOT NULL DEFAULT 'standard' AFTER category;

ALTER TABLE properties
  ADD CONSTRAINT chk_properties_segment CHECK (segment IN ('standard', 'parcel'));
