-- =============================================================================
-- LifeTime — Limpieza de datos para pruebas (SOLO desarrollo / staging)
-- =============================================================================
-- Ejecutar en: Supabase Dashboard → SQL Editor
-- Recomendado: rol service_role (bypass RLS) o conectar con `supabase db execute`
--
-- NO ejecutar en producción con usuarios reales.
-- La app guarda hitos en Isar local: tras limpiar Supabase, borra datos de la app
-- o reinstala para evitar desincronización.
--
-- Storage (bucket avatars): Supabase bloquea DELETE directo en storage.objects.
-- Vacíalo con Dashboard → Storage → avatars, o con empty_avatars_bucket.ps1
-- =============================================================================

-- ─── Opción A: Borrar datos de UN usuario (por email) ───────────────────────
-- Descomenta y cambia el email:

/*
DO $$
DECLARE
  v_email text := 'tu@email.com';
  v_uid uuid;
BEGIN
  SELECT id INTO v_uid FROM auth.users WHERE email = v_email;
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No hay usuario con email %', v_email;
  END IF;

  DELETE FROM public.contact_person_group_links WHERE user_id = v_uid;
  DELETE FROM public.person_groups WHERE user_id = v_uid;
  DELETE FROM public.custom_categories WHERE user_id = v_uid;
  DELETE FROM public.saved_locations WHERE user_id = v_uid;
  DELETE FROM public.milestone_person_links WHERE user_id = v_uid;
  DELETE FROM public.person_relationships WHERE user_id = v_uid;
  DELETE FROM public.contact_people WHERE user_id = v_uid;
  DELETE FROM public.milestones WHERE user_id = v_uid;

  UPDATE public.profiles
  SET
    full_name = NULL,
    avatar_url = NULL,
    is_premium = false,
    updated_at = now()
  WHERE id = v_uid;

  RAISE NOTICE 'Datos borrados para % (%)', v_email, v_uid;
END $$;
*/

-- ─── Opción B: Vaciar TODAS las tablas de la app (todos los usuarios) ─────────
-- Descomenta el bloque siguiente:

/*
BEGIN;

  TRUNCATE TABLE public.contact_person_group_links RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.person_groups RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.custom_categories RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.saved_locations RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.milestone_person_links RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.person_relationships RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.contact_people RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.milestones RESTART IDENTITY CASCADE;

  UPDATE public.profiles
  SET
    full_name = NULL,
    avatar_url = NULL,
    is_premium = false,
    updated_at = now();

COMMIT;
*/

-- ─── Opción C: Reset total (auth + perfil + datos) — máximo cuidado ───────────
-- Borra TODOS los usuarios de auth; en cascada cae profiles y tablas con FK.
-- Descomenta solo si quieres empezar de cero en el proyecto remoto:

/*
BEGIN;

  TRUNCATE TABLE public.contact_person_group_links RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.person_groups RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.custom_categories RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.saved_locations RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.milestone_person_links RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.person_relationships RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.contact_people RESTART IDENTITY CASCADE;
  TRUNCATE TABLE public.milestones RESTART IDENTITY CASCADE;

  TRUNCATE TABLE public.profiles RESTART IDENTITY CASCADE;

  -- Requiere permisos en auth.users (service_role en dashboard).
  DELETE FROM auth.users;

COMMIT;
*/

-- ─── Comprobación rápida (siempre seguro ejecutar) ───────────────────────────
SELECT 'milestones' AS tabla, count(*) AS filas FROM public.milestones
UNION ALL
SELECT 'contact_people', count(*) FROM public.contact_people
UNION ALL
SELECT 'person_relationships', count(*) FROM public.person_relationships
UNION ALL
SELECT 'milestone_person_links', count(*) FROM public.milestone_person_links
UNION ALL
SELECT 'profiles', count(*) FROM public.profiles;
