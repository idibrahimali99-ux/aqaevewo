-- =============================================================================
-- PostgreSQL فقط (لا تشغّل هذا الملف على MySQL أو MariaDB)
--
-- على MariaDB / MySQL استخدم بدلاً منه:
--   patch_properties_view_publish_mysql.sql
--
-- الفرق: PostgreSQL يستخدم JSONB؛ MySQL/MariaDB يستخدمان LONGTEXT أو JSON.
-- =============================================================================

ALTER TABLE properties
  ADD COLUMN IF NOT EXISTS purpose TEXT NOT NULL DEFAULT 'sale';

ALTER TABLE properties
  ADD COLUMN IF NOT EXISTS details_json JSONB;

ALTER TABLE properties DROP CONSTRAINT IF EXISTS chk_properties_purpose;

ALTER TABLE properties
  ADD CONSTRAINT chk_properties_purpose CHECK (purpose IN ('sale', 'rent'));
