-- إعلانات الرئيسية: وضع العرض (منبثق/سلايدر)، مدة النافذة، نهاية الحملة.
USE vewo;

ALTER TABLE home_promotions
  ADD COLUMN display_mode VARCHAR(20) NOT NULL DEFAULT 'both' COMMENT 'both|slider|popup' AFTER link_target,
  ADD COLUMN popup_duration_sec INT NOT NULL DEFAULT 20 AFTER display_mode,
  ADD COLUMN campaign_ends_at DATETIME(3) NULL AFTER popup_duration_sec,
  ADD COLUMN slot VARCHAR(40) NOT NULL DEFAULT 'home' AFTER campaign_ends_at;
