-- vewo database schema (PostgreSQL)
-- ملاحظة: غيّر كلمات المرور في docker-compose.yml بعد أول تشغيل.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Roles: customer | office | staff | admin
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('customer','office','staff','admin')),
  office_approved BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Properties/posts (زبون يحتاج موافقة admin دائماً، المكتب حسب office_approved)
CREATE TABLE IF NOT EXISTS properties (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_user_id UUID NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  governorate TEXT NOT NULL,
  address_line TEXT NOT NULL,
  category TEXT NOT NULL,
  segment TEXT NOT NULL DEFAULT 'standard' CHECK (segment IN ('standard','parcel')),
  purpose TEXT NOT NULL DEFAULT 'sale' CHECK (purpose IN ('sale','rent')),
  price_iqd BIGINT NOT NULL,
  area_sqm INT NOT NULL,
  description TEXT NOT NULL,
  details_json JSONB,
  views INT NOT NULL DEFAULT 0,
  approval_status TEXT NOT NULL CHECK (approval_status IN ('pending','approved','rejected')) DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS property_media (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  media_type TEXT NOT NULL CHECK (media_type IN ('image','video')),
  storage_key TEXT NOT NULL,
  public_url TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Reels
CREATE TABLE IF NOT EXISTS reels (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
  owner_user_id UUID NOT NULL REFERENCES users(id),
  video_storage_key TEXT NOT NULL,
  video_public_url TEXT NOT NULL,
  caption TEXT NOT NULL DEFAULT '',
  approval_status TEXT NOT NULL CHECK (approval_status IN ('pending','approved','rejected')) DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reel_reactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reel_id UUID NOT NULL REFERENCES reels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reaction_type TEXT NOT NULL CHECK (reaction_type IN ('like')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (reel_id, user_id, reaction_type)
);

CREATE TABLE IF NOT EXISTS reel_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reel_id UUID NOT NULL REFERENCES reels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Chat
-- نوعين:
-- direct: customer <-> office
-- mediated: customer <-> admin و office <-> admin لنفس ticket (customer لا يرى office)
CREATE TABLE IF NOT EXISTS chat_threads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  thread_type TEXT NOT NULL CHECK (thread_type IN ('direct','mediated')),
  customer_user_id UUID REFERENCES users(id),
  office_user_id UUID REFERENCES users(id),
  admin_user_id UUID REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  thread_id UUID NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
  sender_user_id UUID NOT NULL REFERENCES users(id),
  -- visibility:
  -- direct: 'all'
  -- mediated: 'customer_only' OR 'office_only'
  visibility TEXT NOT NULL CHECK (visibility IN ('all','customer_only','office_only')),
  body TEXT NOT NULL DEFAULT '',
  image_storage_key TEXT,
  image_public_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed: Admin الرئيسي (رقمك)
-- كلمة المرور الافتراضية: ChangeMe!123  (hash placeholder)
-- IMPORTANT: استبدل password_hash بهاش حقيقي من الـAPI عند أول تشغيل.
INSERT INTO users (full_name, phone, password_hash, role, office_approved, is_active)
VALUES ('Admin Root', '07871456361', 'PLAIN:ChangeMe!123', 'admin', TRUE, TRUE)
ON CONFLICT (phone) DO NOTHING;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_properties_owner ON properties(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_properties_approval ON properties(approval_status);
CREATE INDEX IF NOT EXISTS idx_reels_approval ON reels(approval_status);
CREATE INDEX IF NOT EXISTS idx_chat_messages_thread ON chat_messages(thread_id, created_at);

