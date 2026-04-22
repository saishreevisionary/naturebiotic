-- SQL MIGRATION: ADD VERIFICATION COLUMNS
-- Execute this in the Supabase SQL Editor

-- 1. Add verification columns to farmers
ALTER TABLE farmers ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE farmers ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES profiles(id);
ALTER TABLE farmers ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

-- 2. Add verification columns to farms
ALTER TABLE farms ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE farms ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES profiles(id);
ALTER TABLE farms ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

-- 3. Add verification columns to crops
ALTER TABLE crops ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE crops ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES profiles(id);
ALTER TABLE crops ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

-- 4. Add verification columns to reports
ALTER TABLE reports ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES profiles(id);
ALTER TABLE reports ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

-- 5. Set default value for existing records (Optional but recommended)
-- UPDATE farmers SET is_verified = TRUE WHERE is_verified IS NULL;
-- UPDATE farms SET is_verified = TRUE WHERE is_verified IS NULL;
-- UPDATE crops SET is_verified = TRUE WHERE is_verified IS NULL;
-- UPDATE reports SET is_verified = TRUE WHERE is_verified IS NULL;
