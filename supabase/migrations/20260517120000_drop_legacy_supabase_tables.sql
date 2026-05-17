-- Deprecación de tablas/columnas legacy no usadas por la app actual.
-- Modelo activo: profiles, milestones, contact_people, person_relationships,
-- milestone_person_links (+ medios en Drive / Isar).
--
-- Idempotente. Ejecutar con: supabase db push
-- En producción: hacer backup y comprobar counts antes.

-- ─── 1. Quitar FKs de milestones hacia tablas legacy ─────────────────────────

DO $$
DECLARE
  r record;
BEGIN
  IF to_regclass('public.milestones') IS NULL THEN
    RETURN;
  END IF;

  FOR r IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class rel ON rel.oid = c.conrelid
    JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
  WHERE nsp.nspname = 'public'
    AND rel.relname = 'milestones'
    AND c.contype = 'f'
    AND c.confrelid IN (
      SELECT oid FROM pg_class
      WHERE relnamespace = 'public'::regnamespace
        AND relname IN (
          'categories',
          'people',
          'media_assets',
          'milestone_media',
          'milestone_people'
        )
    )
  LOOP
    EXECUTE format(
      'ALTER TABLE public.milestones DROP CONSTRAINT IF EXISTS %I',
      r.conname
    );
  END LOOP;
END $$;

-- ─── 2. Limpiar columnas legacy en milestones ────────────────────────────────

DO $$
BEGIN
  IF to_regclass('public.milestones') IS NULL THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'milestones'
      AND column_name = 'event_date'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'milestones'
      AND column_name = 'milestone_date'
  ) THEN
    EXECUTE $sql$
      UPDATE public.milestones
      SET milestone_date = event_date
      WHERE milestone_date IS NULL
        AND event_date IS NOT NULL
    $sql$;
  END IF;

  ALTER TABLE public.milestones
    DROP COLUMN IF EXISTS category_id,
    DROP COLUMN IF EXISTS is_favorite,
    DROP COLUMN IF EXISTS participants,
    DROP COLUMN IF EXISTS event_date;
END $$;

COMMENT ON COLUMN public.milestones.milestone_date IS
  'Fecha del hito (canónica). Sincronizada desde la app.';

COMMENT ON COLUMN public.milestones.category IS
  'Id de categoría (texto, p. ej. familia, viajes). Sin FK a tabla categories.';

COMMENT ON COLUMN public.milestones.participant_ids IS
  'Ids de persona (client_id Isar). Enlaces detallados en milestone_person_links.';

-- ─── 3. Eliminar tablas legacy ─────────────────────────────────────────────

DROP TABLE IF EXISTS public.milestone_people CASCADE;
DROP TABLE IF EXISTS public.milestone_media CASCADE;
DROP TABLE IF EXISTS public.media_assets CASCADE;
DROP TABLE IF EXISTS public.relationships CASCADE;
DROP TABLE IF EXISTS public.people CASCADE;
DROP TABLE IF EXISTS public.categories CASCADE;
