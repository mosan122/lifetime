-- Bucket público para fotos de perfil (subida desde la app).
-- Ejecutar ANTES de 20260509120300_avatars_storage_rls_fix.sql en proyectos nuevos.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set public = excluded.public;
