-- أخبار العقارات (عنوان + صورة + وصف كامل) — آمن عند إعادة التشغيل
CREATE TABLE IF NOT EXISTS property_news (
  id CHAR(36) NOT NULL,
  title VARCHAR(255) NOT NULL,
  image_url VARCHAR(1000) NOT NULL,
  body MEDIUMTEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_property_news_active_sort (is_active, sort_order, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
