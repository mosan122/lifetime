-- Corrección RLS avatars + lectura de buckets.
-- Requisito: debe existir el bucket `avatars` (migración 20260509120100 o creación manual en Dashboard).

-- storage.objects
drop policy if exists "avatars_public_read" on storage.objects;
drop policy if exists "avatars_authenticated_insert_own_folder" on storage.objects;
drop policy if exists "avatars_authenticated_update_own_folder" on storage.objects;
drop policy if exists "avatars_authenticated_delete_own_folder" on storage.objects;

create policy "avatars_public_read"
  on storage.objects for select
  using (bucket_id = 'avatars');

-- Primera carpeta del path = UUID del usuario (mismo formato que auth.uid()).
create policy "avatars_authenticated_insert_own_folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and split_part(name, '/', 1) = (select auth.uid()::text)
  );

-- Upsert / sobrescritura requiere UPDATE (y SELECT, cubierto por avatars_public_read).
create policy "avatars_authenticated_update_own_folder"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and split_part(name, '/', 1) = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'avatars'
    and split_part(name, '/', 1) = (select auth.uid()::text)
  );

create policy "avatars_authenticated_delete_own_folder"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and split_part(name, '/', 1) = (select auth.uid()::text)
  );

-- storage.buckets: sin lectura del bucket el cliente puede fallar al resolver el bucket.
drop policy if exists "avatars_bucket_select_authenticated" on storage.buckets;
create policy "avatars_bucket_select_authenticated"
  on storage.buckets for select
  to authenticated
  using (id = 'avatars');

drop policy if exists "avatars_bucket_select_anon" on storage.buckets;
create policy "avatars_bucket_select_anon"
  on storage.buckets for select
  to anon
  using (id = 'avatars');
