-- vewo database schema (MariaDB / MySQL 8+)
-- استخدم هذا الملف إذا كان سيرفرك MariaDB وليس PostgreSQL.
-- ترميز عربي كامل:
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

CREATE DATABASE IF NOT EXISTS vewo
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE vewo;

CREATE TABLE IF NOT EXISTS parcels (
  id CHAR(36) NOT NULL,
  governorate VARCHAR(100) NOT NULL,
  parcel_name VARCHAR(255) NOT NULL,
  parcel_no VARCHAR(40) NOT NULL DEFAULT '',
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_parcels_unique (governorate, parcel_name, parcel_no),
  KEY idx_parcels_active_sort (is_active, sort_order, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Roles: customer | office | staff | admin
CREATE TABLE IF NOT EXISTS users (
  id CHAR(36) NOT NULL,
  full_name VARCHAR(255) NOT NULL,
  office_name VARCHAR(255) NOT NULL DEFAULT '',
  phone VARCHAR(20) NOT NULL,
  email VARCHAR(255) NULL,
  office_address VARCHAR(500) NOT NULL DEFAULT '',
  office_license_no VARCHAR(120) NOT NULL DEFAULT '',
  office_photo_url VARCHAR(1000) NOT NULL DEFAULT '',
  password_hash VARCHAR(500) NOT NULL,
  role VARCHAR(20) NOT NULL,
  office_approved TINYINT(1) NOT NULL DEFAULT 0,
  office_verified TINYINT(1) NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_by CHAR(36) NULL,
  staff_permissions_json JSON NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_phone (phone),
  UNIQUE KEY uq_users_email (email),
  CONSTRAINT chk_users_role CHECK (role IN ('customer','office','staff','admin')),
  CONSTRAINT fk_users_created_by FOREIGN KEY (created_by) REFERENCES users(id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS properties (
  id CHAR(36) NOT NULL,
  property_public_no INT UNSIGNED NULL UNIQUE,
  owner_user_id CHAR(36) NOT NULL,
  parcel_id CHAR(36) NULL,
  title VARCHAR(255) NOT NULL,
  governorate VARCHAR(100) NOT NULL,
  address_line VARCHAR(500) NOT NULL,
  category VARCHAR(50) NOT NULL,
  segment VARCHAR(20) NOT NULL DEFAULT 'standard',
  purpose VARCHAR(20) NOT NULL DEFAULT 'sale',
  price_iqd BIGINT NOT NULL,
  area_sqm INT NOT NULL,
  description TEXT NOT NULL,
  details_json LONGTEXT NULL,
  views INT NOT NULL DEFAULT 0,
  approval_status VARCHAR(20) NOT NULL DEFAULT 'pending',
  is_sold TINYINT(1) NOT NULL DEFAULT 0,
  sold_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT chk_properties_segment CHECK (segment IN ('standard','parcel')),
  CONSTRAINT chk_properties_purpose CHECK (purpose IN ('sale','rent')),
  CONSTRAINT chk_properties_approval CHECK (approval_status IN ('pending','approved','rejected')),
  CONSTRAINT fk_properties_owner FOREIGN KEY (owner_user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
  ,CONSTRAINT fk_properties_parcel FOREIGN KEY (parcel_id) REFERENCES parcels(id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS property_media (
  id CHAR(36) NOT NULL,
  property_id CHAR(36) NOT NULL,
  media_type VARCHAR(20) NOT NULL,
  storage_key VARCHAR(500) NOT NULL,
  public_url VARCHAR(1000) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT chk_property_media_type CHECK (media_type IN ('image','video')),
  CONSTRAINT fk_property_media_property FOREIGN KEY (property_id) REFERENCES properties(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS reels (
  id CHAR(36) NOT NULL,
  property_id CHAR(36) NULL,
  owner_user_id CHAR(36) NOT NULL,
  video_storage_key VARCHAR(500) NOT NULL,
  video_public_url VARCHAR(1000) NOT NULL,
  caption VARCHAR(500) NOT NULL DEFAULT '',
  comments_enabled TINYINT(1) NOT NULL DEFAULT 1,
  approval_status VARCHAR(20) NOT NULL DEFAULT 'pending',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT chk_reels_approval CHECK (approval_status IN ('pending','approved','rejected')),
  CONSTRAINT fk_reels_property FOREIGN KEY (property_id) REFERENCES properties(id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_reels_owner FOREIGN KEY (owner_user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS reel_reactions (
  id CHAR(36) NOT NULL,
  reel_id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  reaction_type VARCHAR(20) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_reel_reaction (reel_id, user_id, reaction_type),
  CONSTRAINT chk_reel_reaction_type CHECK (reaction_type IN ('like')),
  CONSTRAINT fk_reel_reactions_reel FOREIGN KEY (reel_id) REFERENCES reels(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_reel_reactions_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS reel_comments (
  id CHAR(36) NOT NULL,
  reel_id CHAR(36) NOT NULL,
  parent_comment_id CHAR(36) NULL,
  user_id CHAR(36) NOT NULL,
  body TEXT NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  INDEX idx_reel_comments_parent (parent_comment_id),
  CONSTRAINT fk_reel_comments_reel FOREIGN KEY (reel_id) REFERENCES reels(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_reel_comments_parent FOREIGN KEY (parent_comment_id) REFERENCES reel_comments(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_reel_comments_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

CREATE TABLE IF NOT EXISTS chat_threads (
  id CHAR(36) NOT NULL,
  thread_public_no INT UNSIGNED NULL UNIQUE,
  thread_type VARCHAR(20) NOT NULL,
  customer_user_id CHAR(36) NULL,
  office_user_id CHAR(36) NULL,
  admin_user_id CHAR(36) NULL,
  property_id CHAR(36) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT chk_chat_thread_type CHECK (thread_type IN ('direct','mediated')),
  CONSTRAINT fk_chat_threads_customer FOREIGN KEY (customer_user_id) REFERENCES users(id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_chat_threads_office FOREIGN KEY (office_user_id) REFERENCES users(id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_chat_threads_admin FOREIGN KEY (admin_user_id) REFERENCES users(id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS chat_messages (
  id CHAR(36) NOT NULL,
  thread_id CHAR(36) NOT NULL,
  sender_user_id CHAR(36) NOT NULL,
  visibility VARCHAR(30) NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  image_storage_key VARCHAR(500) NULL,
  image_public_url VARCHAR(1000) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT chk_chat_visibility CHECK (visibility IN ('all','customer_only','office_only')),
  CONSTRAINT fk_chat_messages_thread FOREIGN KEY (thread_id) REFERENCES chat_threads(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_chat_messages_sender FOREIGN KEY (sender_user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

CREATE TABLE IF NOT EXISTS user_session_tokens (
  token CHAR(64) NOT NULL PRIMARY KEY,
  user_id CHAR(36) NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  KEY idx_user_sess_user (user_id),
  KEY idx_user_sess_exp (expires_at),
  CONSTRAINT fk_user_sess_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS home_promotions (
  id CHAR(36) NOT NULL,
  title VARCHAR(255) NOT NULL,
  subtitle VARCHAR(500) NOT NULL DEFAULT '',
  image_url VARCHAR(1000) NOT NULL,
  link_type VARCHAR(20) NOT NULL DEFAULT 'none',
  link_target VARCHAR(500) NOT NULL DEFAULT '',
  display_mode VARCHAR(20) NOT NULL DEFAULT 'both',
  popup_duration_sec INT NOT NULL DEFAULT 20,
  campaign_ends_at DATETIME(3) NULL,
  slot VARCHAR(40) NOT NULL DEFAULT 'home',
  sort_order INT NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT chk_home_promo_link CHECK (link_type IN ('none','property','url')),
  CONSTRAINT chk_home_promo_mode CHECK (display_mode IN ('both','slider','popup'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

-- أدمن رئيسي: هاتف 07871456361 | كلمة المرور ChangeMe!123 | تطبيق vewo_admin يستخدم auth/admin/login
-- لتغيير الحساب أو الإنشاء يدوياً: php api/scripts/create_admin.php ...
INSERT IGNORE INTO users (id, full_name, office_name, phone, office_address, office_license_no, office_photo_url, password_hash, role, office_approved, is_active, created_by, created_at)
VALUES (UUID(), 'Admin Root', '', '07871456361', '', '', '', 'PLAIN:ChangeMe!Admin2026', 'admin', 1, 1, NULL, NOW(3));

-- فهارس (آمنة عند إعادة تنفيذ الملف — لا تعيد إنشاء الاسم إن وُجد)
SET @idx_exists = (SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'users' AND index_name = 'idx_users_role');
SET @sql = IF(@idx_exists = 0, 'ALTER TABLE users ADD INDEX idx_users_role (role)', 'SELECT 1');
PREPARE _vewo_idx FROM @sql;
EXECUTE _vewo_idx;
DEALLOCATE PREPARE _vewo_idx;

SET @idx_exists = (SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'properties' AND index_name = 'idx_properties_owner');
SET @sql = IF(@idx_exists = 0, 'ALTER TABLE properties ADD INDEX idx_properties_owner (owner_user_id)', 'SELECT 1');
PREPARE _vewo_idx FROM @sql;
EXECUTE _vewo_idx;
DEALLOCATE PREPARE _vewo_idx;

SET @idx_exists = (SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'properties' AND index_name = 'idx_properties_approval');
SET @sql = IF(@idx_exists = 0, 'ALTER TABLE properties ADD INDEX idx_properties_approval (approval_status)', 'SELECT 1');
PREPARE _vewo_idx FROM @sql;
EXECUTE _vewo_idx;
DEALLOCATE PREPARE _vewo_idx;

SET @idx_exists = (SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'reels' AND index_name = 'idx_reels_approval');
SET @sql = IF(@idx_exists = 0, 'ALTER TABLE reels ADD INDEX idx_reels_approval (approval_status)', 'SELECT 1');
PREPARE _vewo_idx FROM @sql;
EXECUTE _vewo_idx;
DEALLOCATE PREPARE _vewo_idx;

SET @idx_exists = (SELECT COUNT(*) FROM information_schema.statistics
  WHERE table_schema = DATABASE() AND table_name = 'chat_messages' AND index_name = 'idx_chat_messages_thread');
SET @sql = IF(@idx_exists = 0, 'ALTER TABLE chat_messages ADD INDEX idx_chat_messages_thread (thread_id, created_at)', 'SELECT 1');
PREPARE _vewo_idx FROM @sql;
EXECUTE _vewo_idx;
DEALLOCATE PREPARE _vewo_idx;
