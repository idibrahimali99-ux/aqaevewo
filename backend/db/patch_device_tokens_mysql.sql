-- Device tokens for FCM push notifications

CREATE TABLE IF NOT EXISTS device_tokens (
  id CHAR(36) NOT NULL,
  token VARCHAR(255) NOT NULL,
  user_id CHAR(36) NULL,
  is_admin_app TINYINT(1) NOT NULL DEFAULT 0,
  platform VARCHAR(20) NOT NULL DEFAULT '',
  last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uniq_device_token (token),
  KEY idx_device_user (user_id, is_admin_app),
  KEY idx_device_seen (last_seen_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

