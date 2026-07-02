-- حصص نشر المنشورات للمكاتب (role = office).
-- posting_trial_unlimited = 1 : تجريبي مفتوح — لا يُخصم من الرصيد ولا يُرفض النشر.
-- posting_trial_unlimited = 0 : رصد الباقة؛ يُسمح بالنشر طالما posting_listings_remaining > 0.

ALTER TABLE users
  ADD COLUMN posting_trial_unlimited TINYINT(1) NOT NULL DEFAULT 1
    COMMENT '1=trial open unlimited posts'
    AFTER office_approved,
  ADD COLUMN posting_listings_remaining INT NULL DEFAULT NULL
    COMMENT 'slots left when trial off; NULL treated as 0 when enforced'
    AFTER posting_trial_unlimited;
