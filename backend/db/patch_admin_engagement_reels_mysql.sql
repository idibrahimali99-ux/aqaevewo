-- جدولة زيادة مشاهدات/لايكات للمنشورات والريلز + أرقام عامة للريلز ومشاهدات عرض
-- نفّذ مرة واحدة على قاعدة الإنتاج.

SET @db := DATABASE();

-- reels: رقم عام للبحث، عداد مشاهدات عرض، لايكات تركيبية (تُجمع مع reel_reactions في الواجهات)
SET @exists := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'reels' AND column_name = 'reel_public_no');
SET @sql := IF(@exists = 0,
  'ALTER TABLE reels ADD COLUMN reel_public_no INT UNSIGNED NULL UNIQUE COMMENT ''رقم يظهر للمستخدم'' AFTER id',
  'SELECT 1');
PREPARE s1 FROM @sql; EXECUTE s1; DEALLOCATE PREPARE s1;

SET @exists := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'reels' AND column_name = 'view_count');
SET @sql := IF(@exists = 0,
  'ALTER TABLE reels ADD COLUMN view_count INT NOT NULL DEFAULT 0 AFTER caption',
  'SELECT 1');
PREPARE s2 FROM @sql; EXECUTE s2; DEALLOCATE PREPARE s2;

SET @exists := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'reels' AND column_name = 'synthetic_likes');
SET @sql := IF(@exists = 0,
  'ALTER TABLE reels ADD COLUMN synthetic_likes INT NOT NULL DEFAULT 0 AFTER view_count',
  'SELECT 1');
PREPARE s3 FROM @sql; EXECUTE s3; DEALLOCATE PREPARE s3;

CREATE TABLE IF NOT EXISTS admin_engagement_rules (
  id CHAR(36) NOT NULL,
  target_kind VARCHAR(20) NOT NULL,
  target_public_no INT UNSIGNED NOT NULL,
  views_per_tick INT NOT NULL DEFAULT 0,
  likes_per_tick INT NOT NULL DEFAULT 0,
  interval_seconds INT NOT NULL DEFAULT 60,
  last_tick_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_engagement_kind_pub (target_kind, target_public_no),
  CONSTRAINT chk_engagement_kind CHECK (target_kind IN ('property','reel'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
