-- إيصالات قراءة المحادثة (مستفسر + أدمن) لعرض «تمت المشاهدة»
SET @db := DATABASE();

SET @exists := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'chat_threads' AND column_name = 'customer_last_read_at');
SET @sql := IF(@exists = 0,
  'ALTER TABLE chat_threads ADD COLUMN customer_last_read_at DATETIME(3) NULL AFTER admin_unread_count',
  'SELECT 1');
PREPARE s1 FROM @sql; EXECUTE s1; DEALLOCATE PREPARE s1;

SET @exists := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'chat_threads' AND column_name = 'admin_last_read_at');
SET @sql := IF(@exists = 0,
  'ALTER TABLE chat_threads ADD COLUMN admin_last_read_at DATETIME(3) NULL AFTER customer_last_read_at',
  'SELECT 1');
PREPARE s2 FROM @sql; EXECUTE s2; DEALLOCATE PREPARE s2;
