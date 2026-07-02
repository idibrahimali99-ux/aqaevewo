-- ربط المحادثات بالريلز (سياق «تواصل» من الريلز)
SET @db := DATABASE();

SET @has := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'chat_threads' AND column_name = 'reel_id'
);
SET @sql := IF(
  @has = 0,
  'ALTER TABLE chat_threads ADD COLUMN reel_id CHAR(36) NULL AFTER property_id',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx := (
  SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = @db AND table_name = 'chat_threads' AND index_name = 'idx_chat_threads_reel'
);
SET @sql2 := IF(
  @idx = 0,
  'ALTER TABLE chat_threads ADD INDEX idx_chat_threads_reel (reel_id, customer_user_id)',
  'SELECT 1'
);
PREPARE stmt2 FROM @sql2;
EXECUTE stmt2;
DEALLOCATE PREPARE stmt2;
