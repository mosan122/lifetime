-- supabase/migrations/20260426000000_add_participants_to_milestones.sql
ALTER TABLE milestones
  ADD COLUMN IF NOT EXISTS participants TEXT[] DEFAULT '{}';
