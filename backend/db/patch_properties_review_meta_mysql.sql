-- ملاحظات الرفض وإعادة الإرسال بعد التعديل (لوحة الأدمن + إشعار للناشر)
USE vewo;

ALTER TABLE properties
  ADD COLUMN reject_note VARCHAR(2000) NULL DEFAULT NULL,
  ADD COLUMN resubmission_allowed TINYINT(1) NOT NULL DEFAULT 0;
