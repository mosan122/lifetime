-- Proyectos con columna legacy milestone_date (NOT NULL).
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS milestone_date timestamptz;

UPDATE public.milestones
SET milestone_date = event_date
WHERE milestone_date IS NULL
  AND event_date IS NOT NULL;

UPDATE public.milestones
SET event_date = milestone_date
WHERE event_date IS NULL
  AND milestone_date IS NOT NULL;
