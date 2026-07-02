-- تصفير منشورات العقارات والريلز للتجربة (يحافظ على المستخدمين والجلسات)
-- ⚠️ ينفّذ حذفاً نهائياً — راجع قبل التشغيل

USE vewo;

SET NAMES utf8mb4;

SET FOREIGN_KEY_CHECKS = 0;

DELETE FROM reel_comments;
DELETE FROM reel_reactions;
DELETE FROM reels;

DELETE FROM property_media;
DELETE FROM properties;

SET FOREIGN_KEY_CHECKS = 1;

-- اختياري: محادثات مرتبطة بمنشورات (إن وُجدت أعمدة property_id في threads)
-- DELETE FROM chat_messages WHERE thread_id IN (SELECT id FROM chat_threads WHERE property_id IS NOT NULL);
-- DELETE FROM chat_threads WHERE property_id IS NOT NULL;
