-- نفّذ هذا الملف على قاعدة vewo **الموجودة مسبقاً** إن لم تُنشأ الجداول بعد.
USE vewo;

CREATE TABLE IF NOT EXISTS admin_api_tokens (
  token CHAR(64) NOT NULL,
  user_id CHAR(36) NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (token),
  KEY idx_admin_tokens_user (user_id),
  KEY idx_admin_tokens_expires (expires_at),
  CONSTRAINT fk_admin_tokens_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS home_promotions (
  id CHAR(36) NOT NULL,
  title VARCHAR(255) NOT NULL,
  subtitle VARCHAR(500) NOT NULL DEFAULT '',
  image_url VARCHAR(1000) NOT NULL,
  link_type VARCHAR(20) NOT NULL DEFAULT 'none',
  link_target VARCHAR(500) NOT NULL DEFAULT '',
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT chk_home_promo_link CHECK (link_type IN ('none','property','url'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
