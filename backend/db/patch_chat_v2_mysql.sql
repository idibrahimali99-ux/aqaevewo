-- Patch v2: chat unread counters + last message + media (audio/image) unified
-- Safe to run multiple times.
SET NAMES utf8mb4;

-- chat_threads: add last message + unread counters
SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'chat_threads' AND column_name = 'last_message_at'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE chat_threads ADD COLUMN last_message_at DATETIME(3) NULL AFTER created_at',
  'SELECT 1');
PREPARE _vewo_patch FROM @sql; EXECUTE _vewo_patch; DEALLOCATE PREPARE _vewo_patch;

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'chat_threads' AND column_name = 'last_message_preview'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE chat_threads ADD COLUMN last_message_preview VARCHAR(400) NOT NULL DEFAULT \"\" AFTER last_message_at',
  'SELECT 1');
PREPARE _vewo_patch FROM @sql; EXECUTE _vewo_patch; DEALLOCATE PREPARE _vewo_patch;

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'chat_threads' AND column_name = 'customer_unread_count'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE chat_threads ADD COLUMN customer_unread_count INT NOT NULL DEFAULT 0 AFTER last_message_preview',
  'SELECT 1');
PREPARE _vewo_patch FROM @sql; EXECUTE _vewo_patch; DEALLOCATE PREPARE _vewo_patch;

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'chat_threads' AND column_name = 'office_unread_count'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE chat_threads ADD COLUMN office_unread_count INT NOT NULL DEFAULT 0 AFTER customer_unread_count',
  'SELECT 1');
PREPARE _vewo_patch FROM @sql; EXECUTE _vewo_patch; DEALLOCATE PREPARE _vewo_patch;

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'chat_threads' AND column_name = 'admin_unread_count'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE chat_threads ADD COLUMN admin_unread_count INT NOT NULL DEFAULT 0 AFTER office_unread_count',
  'SELECT 1');
PREPARE _vewo_patch FROM @sql; EXECUTE _vewo_patch; DEALLOCATE PREPARE _vewo_patch;

-- chat_messages: unify media fields (image/audio)
SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'chat_messages' AND column_name = 'media_type'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE chat_messages ADD COLUMN media_type VARCHAR(20) NOT NULL DEFAULT \"none\" AFTER body',
  'SELECT 1');
PREPARE _vewo_patch FROM @sql; EXECUTE _vewo_patch; DEALLOCATE PREPARE _vewo_patch;

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'chat_messages' AND column_name = 'media_storage_key'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE chat_messages ADD COLUMN media_storage_key VARCHAR(500) NULL AFTER media_type',
  'SELECT 1');
PREPARE _vewo_patch FROM @sql; EXECUTE _vewo_patch; DEALLOCATE PREPARE _vewo_patch;

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'chat_messages' AND column_name = 'media_public_url'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE chat_messages ADD COLUMN media_public_url VARCHAR(1000) NULL AFTER media_storage_key',
  'SELECT 1');
PREPARE _vewo_patch FROM @sql; EXECUTE _vewo_patch; DEALLOCATE PREPARE _vewo_patch;

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'chat_messages' AND column_name = 'duration_ms'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE chat_messages ADD COLUMN duration_ms INT NULL AFTER media_public_url',
  'SELECT 1');
PREPARE _vewo_patch FROM @sql; EXECUTE _vewo_patch; DEALLOCATE PREPARE _vewo_patch;

-- Backfill: move legacy image_public_url/storage_key into media_* for older rows (best-effort)
UPDATE chat_messages
SET media_type = 'image',
    media_public_url = COALESCE(media_public_url, image_public_url),
    media_storage_key = COALESCE(media_storage_key, image_storage_key)
WHERE (media_type = 'none' OR media_type = '' OR media_type IS NULL)
  AND (image_public_url IS NOT NULL AND image_public_url <> '');

-- Index helpers
SET @idx_exists = (SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'chat_threads' AND index_name = 'idx_chat_threads_last');
SET @sql = IF(@idx_exists = 0,
  'ALTER TABLE chat_threads ADD INDEX idx_chat_threads_last (last_message_at, created_at)',
  'SELECT 1');
PREPARE _vewo_idx FROM @sql; EXECUTE _vewo_idx; DEALLOCATE PREPARE _vewo_idx;

