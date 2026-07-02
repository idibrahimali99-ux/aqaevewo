-- تشغيل مرة واحدة على قاعدة vewo الموجودة:
-- جلسات تطبيق الزبون (Bearer) + ربط المحادثة بمنشور عقار

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS user_session_tokens (
  token CHAR(64) NOT NULL PRIMARY KEY,
  user_id CHAR(36) NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  KEY idx_user_sess_user (user_id),
  KEY idx_user_sess_exp (expires_at),
  CONSTRAINT fk_user_sess_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- عمود اختياري: عند التواصل من صفحة عقار يُخزَّن معرّف المنشور (قد لا يوجد في الجدول إن كان عقاراً محلياً فقط)
SET @col_exists = (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'chat_threads' AND column_name = 'property_id'
);
SET @sql = IF(@col_exists = 0,
  'ALTER TABLE chat_threads ADD COLUMN property_id CHAR(36) NULL AFTER admin_user_id',
  'SELECT 1');
PREPARE _vewo_patch FROM @sql;
EXECUTE _vewo_patch;
DEALLOCATE PREPARE _vewo_patch;
