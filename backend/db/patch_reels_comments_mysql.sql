-- Reels comments, replies, comment likes, and comment disabling.
-- Safe to run multiple times.
SET NAMES utf8mb4;

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'reels' AND column_name = 'comments_enabled'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE reels ADD COLUMN comments_enabled TINYINT(1) NOT NULL DEFAULT 1 AFTER caption',
  'SELECT 1');
PREPARE _vewo_reels_comments_enabled FROM @sql; EXECUTE _vewo_reels_comments_enabled; DEALLOCATE PREPARE _vewo_reels_comments_enabled;

SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'reel_comments' AND column_name = 'parent_comment_id'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE reel_comments ADD COLUMN parent_comment_id CHAR(36) NULL AFTER reel_id',
  'SELECT 1');
PREPARE _vewo_reel_comments_parent FROM @sql; EXECUTE _vewo_reel_comments_parent; DEALLOCATE PREPARE _vewo_reel_comments_parent;

SET @idx_exists = (
  SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'reel_comments' AND index_name = 'idx_reel_comments_parent'
);
SET @sql = IF(@idx_exists = 0,
  'ALTER TABLE reel_comments ADD INDEX idx_reel_comments_parent (parent_comment_id)',
  'SELECT 1');
PREPARE _vewo_reel_comments_parent_idx FROM @sql; EXECUTE _vewo_reel_comments_parent_idx; DEALLOCATE PREPARE _vewo_reel_comments_parent_idx;

CREATE TABLE IF NOT EXISTS reel_comment_likes (
  id CHAR(36) NOT NULL,
  comment_id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_reel_comment_like (comment_id, user_id),
  CONSTRAINT fk_reel_comment_likes_comment FOREIGN KEY (comment_id) REFERENCES reel_comments(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_reel_comment_likes_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
