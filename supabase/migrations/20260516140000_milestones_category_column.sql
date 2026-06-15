-- Columna usada por la app al sincronizar hitos (MilestoneModel.toInsertMap → 'category').
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS category text;

COMMENT ON COLUMN public.milestones.category IS
  'Identificador de categoría del hito (p. ej. familia, viajes, otros).';
