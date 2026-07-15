-- باقات/اشتراكات المسوقين والمكاتب: مدة الاشتراك وتاريخ الانتهاء.
-- آمن للتشغيل أكثر من مرة.

SET NAMES utf8mb4;

SET @_c := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users'
    AND column_name = 'posting_subscription_days'
);
SET @_sql := IF(@_c = 0,
  'ALTER TABLE users ADD COLUMN posting_subscription_days INT NULL AFTER posting_package_id',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @_c := (
  SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users'
    AND column_name = 'posting_subscription_expires_at'
);
SET @_sql := IF(@_c = 0,
  'ALTER TABLE users ADD COLUMN posting_subscription_expires_at DATETIME NULL AFTER posting_subscription_days',
  'SELECT 1');
PREPARE s FROM @_sql; EXECUTE s; DEALLOCATE PREPARE s;

