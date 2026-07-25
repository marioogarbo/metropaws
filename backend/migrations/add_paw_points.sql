-- MetroPaws: PawPoints MVP migration
-- Run this in the Supabase SQL editor BEFORE deploying the updated backend.

-- 1. Transaction ledger (one row per earn/spend event)
CREATE TABLE IF NOT EXISTS paw_points_transactions (
    id            TEXT PRIMARY KEY,
    member_id     TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    points        INTEGER NOT NULL,
    activity_type TEXT NOT NULL,
    reference_id  TEXT,
    notes         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ppt_member_id ON paw_points_transactions(member_id);

-- 2. Rewards catalogue
CREATE TABLE IF NOT EXISTS paw_points_rewards (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    description     TEXT,
    points_required INTEGER NOT NULL,
    reward_type     TEXT NOT NULL DEFAULT 'merchandise',
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order      INTEGER NOT NULL DEFAULT 0
);

-- 3. Seed the rewards catalogue from the Member Manual
INSERT INTO paw_points_rewards (id, name, description, points_required, reward_type, is_active, sort_order) VALUES
    (gen_random_uuid()::text, 'Digital Responsible Fur Parent Badge', 'Low-cost recognition reward', 250, 'recognition', TRUE, 1),
    (gen_random_uuid()::text, 'MetroPaws Pet Tag or Sticker Pack', 'Subject to availability', 500, 'merchandise', TRUE, 2),
    (gen_random_uuid()::text, 'Pet Wellness Checklist Kit or Event Priority Slot', 'Designed to support wellness engagement', 750, 'merchandise', TRUE, 3),
    (gen_random_uuid()::text, 'PHP 100 Wellness Credit', 'Subject to reward budget and program rules', 1000, 'credit', TRUE, 4),
    (gen_random_uuid()::text, 'Grooming Add-On or Nail Trim Voucher', 'Partner availability may apply', 1500, 'voucher', TRUE, 5),
    (gen_random_uuid()::text, 'Premium Member Gift Pack or VIP Event Access', 'Ideal for Premium and loyal members', 2500, 'merchandise', TRUE, 6),
    (gen_random_uuid()::text, 'Special Annual Recognition Reward', 'For top engaged members only', 5000, 'recognition', TRUE, 7)
ON CONFLICT DO NOTHING;
