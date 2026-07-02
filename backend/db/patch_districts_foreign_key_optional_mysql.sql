-- ============================================================================
-- اختياري — FOREIGN KEY بين districts و governorates
--
-- إذا ظهر errno 150: أنواع الأعمدة أو COLLATE غير متطابقة. لا تشغّل ADD CONSTRAINT
-- من دون الخطوة (أ) أدناه، أو اترك الجدول بدون FK (التطبيق يعمل بدونه).
--
-- انسخ احتياطياً قبل تحويل ترميز الجداول الكبيرة.
-- ============================================================================

USE vewo;

-- (أ) توحيد الترميز بين الجدولين — غالباً يزيل سبب الخطأ #1005 / errno 150
ALTER TABLE `governorates` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE `districts` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- (ب) إذا كان اسماً قديماً للقيد بعد محاولة فاشلة، احذفه ثم أعد التشغيل:
-- ALTER TABLE `districts` DROP FOREIGN KEY `fk_districts_governorate`;

-- (ج) إضافة القيد
ALTER TABLE `districts`
  ADD CONSTRAINT `fk_districts_governorate`
  FOREIGN KEY (`governorate_id`) REFERENCES `governorates` (`id`)
  ON DELETE CASCADE ON UPDATE CASCADE;
