-- Broadcast messages for all users (polling + local notifications)

CREATE TABLE IF NOT EXISTS broadcast_messages (
  id CHAR(36) NOT NULL,
  title VARCHAR(120) NOT NULL DEFAULT '',
  body TEXT NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_broadcast_active_created (is_active, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

