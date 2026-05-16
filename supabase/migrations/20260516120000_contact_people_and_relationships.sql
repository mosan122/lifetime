-- Local-first sync: contactos y relaciones (premium, RLS por usuario).

create table if not exists public.contact_people (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  client_id text not null,
  name text not null,
  first_name text,
  last_name text,
  birth_date timestamptz,
  notes text not null default '',
  linked_user_email text,
  linked_user_id text,
  drive_face_file_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, client_id)
);

create table if not exists public.person_relationships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  client_id text not null,
  person_id text not null,
  related_person_id text not null,
  relationship_type text not null,
  start_date timestamptz,
  end_date timestamptz,
  is_current boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, client_id)
);

create index if not exists contact_people_user_id_idx
  on public.contact_people (user_id);

create index if not exists person_relationships_user_id_idx
  on public.person_relationships (user_id);

alter table public.contact_people enable row level security;
alter table public.person_relationships enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'contact_people'
      and policyname = 'contact_people_select_own'
  ) then
    create policy contact_people_select_own on public.contact_people
      for select using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'contact_people'
      and policyname = 'contact_people_insert_own'
  ) then
    create policy contact_people_insert_own on public.contact_people
      for insert with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'contact_people'
      and policyname = 'contact_people_update_own'
  ) then
    create policy contact_people_update_own on public.contact_people
      for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'contact_people'
      and policyname = 'contact_people_delete_own'
  ) then
    create policy contact_people_delete_own on public.contact_people
      for delete using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'person_relationships'
      and policyname = 'person_relationships_select_own'
  ) then
    create policy person_relationships_select_own on public.person_relationships
      for select using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'person_relationships'
      and policyname = 'person_relationships_insert_own'
  ) then
    create policy person_relationships_insert_own on public.person_relationships
      for insert with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'person_relationships'
      and policyname = 'person_relationships_update_own'
  ) then
    create policy person_relationships_update_own on public.person_relationships
      for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'person_relationships'
      and policyname = 'person_relationships_delete_own'
  ) then
    create policy person_relationships_delete_own on public.person_relationships
      for delete using (auth.uid() = user_id);
  end if;
end $$;
