-- تم البيع: علَم على المنشور + وقت التعليم (اختياري لعرض الإحصاءات).
USE vewo;

ALTER TABLE properties
  ADD COLUMN is_sold TINYINT(1) NOT NULL DEFAULT 0 AFTER approval_status,
  ADD COLUMN sold_at DATETIME(3) NULL AFTER is_sold;
