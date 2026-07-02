-- رقم عرض للمحادثة (مثل #10052828) + إسناد للجداول الموجودة
SET NAMES utf8mb4;
USE vewo;

SET @col = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'chat_threads' AND column_name = 'thread_public_no');
SET @sql = IF(@col = 0,
  'ALTER TABLE chat_threads ADD COLUMN thread_public_no INT UNSIGNED NULL UNIQUE COMMENT ''رقم يظهر في التطبيق'' AFTER id',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ترقيم تسلسلي من 10000001
SET @n = 10000000;
UPDATE chat_threads
  SET thread_public_no = (@n := @n + 1)
  WHERE thread_public_no IS NULL
  ORDER BY created_at ASC;
