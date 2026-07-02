-- Governorates management (admin can rename/disable)
-- MySQL 5.7+ (InnoDB)

CREATE TABLE IF NOT EXISTS governorates (
  id CHAR(36) NOT NULL,
  name VARCHAR(80) NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_governorates_active_sort (is_active, sort_order, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Optional seed (run once). If you already inserted, ignore duplicates manually.
-- INSERT INTO governorates (id, name, is_active, sort_order) VALUES
--   (UUID(), 'بغداد', 1, 10),
--   (UUID(), 'البصرة', 1, 20);

