-- Adds semantic metadata fields to milestones for premium updates.
ALTER TABLE milestones
  ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';

ALTER TABLE milestones
  ADD COLUMN IF NOT EXISTS participant_ids TEXT[] DEFAULT '{}';

