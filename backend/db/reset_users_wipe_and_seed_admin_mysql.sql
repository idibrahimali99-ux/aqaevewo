-- =============================================================================
-- خطر: يحذف كل المستخدمين وجميع البيانات المرتبطة بهم (عقارات، محادثات، …)
-- ثم ينشئ حساب مسؤول واحد فقط.
--
-- نفّذ على قاعدة vewo بعد أخذ نسخة احتياطية.
-- الهاتف الافتراضي: 07871456361 | كلمة المرور: ChangeMe!Admin2026
-- غيّر القيم في الأسفل إن رغبت، ثم نفّذ الملف.
-- إذا عمود office_name غير موجود، نفّذ أولاً: patch_office_name_mysql.sql
-- =============================================================================

USE vewo;

SET @c = (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_name');
SET @sql = IF(@c = 0,
  'ALTER TABLE users ADD COLUMN office_name VARCHAR(255) NOT NULL DEFAULT \'\' AFTER full_name',
  'SELECT 1');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

DELETE FROM chat_messages;
DELETE FROM chat_threads;
DELETE FROM admin_api_tokens;
DELETE FROM user_session_tokens;
DELETE FROM reel_reactions;
DELETE FROM reel_comments;
DELETE FROM reels;
DELETE FROM property_media;
DELETE FROM properties;

UPDATE users SET created_by = NULL WHERE created_by IS NOT NULL;
DELETE FROM users;

INSERT INTO users (
  id, full_name, office_name, phone,
  office_address, office_license_no, office_photo_url,
  password_hash, role, office_approved, is_active, created_by, created_at
) VALUES (
  UUID(),
  'Admin Root',
  '',
  '07871456361',
  '', '', '',
  'PLAIN:ChangeMe!Admin2026',
  'admin',
  1, 1, NULL,
  NOW(3)
);

SELECT 'تم. سجّل الدخول في vewo_admin بهاتف 07871456361 وكلمة ChangeMe!Admin2026' AS status;
