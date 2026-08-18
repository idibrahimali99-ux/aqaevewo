-- ملاحظات رفض الريل وإعادة الإرسال بعد التعديل
-- نفّذ مرة واحدة على قاعدة الإنتاج.

SET NAMES utf8mb4;
SET @db := DATABASE();

SET @exists := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'reels' AND column_name = 'reject_note');
SET @sql := IF(@exists = 0,
  'ALTER TABLE reels ADD COLUMN reject_note VARCHAR(2000) NULL DEFAULT NULL AFTER approval_status',
  'SELECT 1');
PREPARE s1 FROM @sql; EXECUTE s1; DEALLOCATE PREPARE s1;

SET @exists := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'reels' AND column_name = 'resubmission_allowed');
SET @sql := IF(@exists = 0,
  'ALTER TABLE reels ADD COLUMN resubmission_allowed TINYINT(1) NOT NULL DEFAULT 0 AFTER reject_note',
  'SELECT 1');
PREPARE s2 FROM @sql; EXECUTE s2; DEALLOCATE PREPARE s2;
