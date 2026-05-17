-- Vaciar datos de app de TODOS los usuarios (dev/staging).
-- Supabase Dashboard → SQL Editor (service_role).
--
-- Storage: NO se puede DELETE en storage.objects por SQL.
-- Después de este script, vacía avatares con:
--   Dashboard → Storage → avatars → seleccionar todo → Delete
-- o ejecuta:  supabase/scripts/empty_avatars_bucket.ps1

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
