-- Catálogo premium en nube: grupos, categorías custom, lugares favoritos.

create table if not exists public.person_groups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  client_id text not null,
  name text not null,
  built_in boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, client_id)
);

create table if not exists public.contact_person_group_links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  person_client_id text not null,
  group_client_id text not null,
  created_at timestamptz not null default now(),
  unique (user_id, person_client_id, group_client_id)
);

create table if not exists public.custom_categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  client_id text not null,
  name text not null,
  icon_name text not null,
  color_value integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, client_id)
);

create table if not exists public.saved_locations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  client_id text not null,
  name text not null,
  city text,
  country text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, client_id)
);

create index if not exists person_groups_user_id_idx
  on public.person_groups (user_id);

create index if not exists contact_person_group_links_user_id_idx
  on public.contact_person_group_links (user_id);

create index if not exists custom_categories_user_id_idx
  on public.custom_categories (user_id);

create index if not exists saved_locations_user_id_idx
  on public.saved_locations (user_id);

alter table public.person_groups enable row level security;
alter table public.contact_person_group_links enable row level security;
alter table public.custom_categories enable row level security;
alter table public.saved_locations enable row level security;

-- person_groups
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'person_groups' and policyname = 'person_groups_select_own') then
    create policy person_groups_select_own on public.person_groups for select using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'person_groups' and policyname = 'person_groups_insert_own') then
    create policy person_groups_insert_own on public.person_groups for insert with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'person_groups' and policyname = 'person_groups_update_own') then
    create policy person_groups_update_own on public.person_groups for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'person_groups' and policyname = 'person_groups_delete_own') then
    create policy person_groups_delete_own on public.person_groups for delete using (auth.uid() = user_id);
  end if;
end $$;

-- contact_person_group_links
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'contact_person_group_links' and policyname = 'contact_person_group_links_select_own') then
    create policy contact_person_group_links_select_own on public.contact_person_group_links for select using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'contact_person_group_links' and policyname = 'contact_person_group_links_insert_own') then
    create policy contact_person_group_links_insert_own on public.contact_person_group_links for insert with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'contact_person_group_links' and policyname = 'contact_person_group_links_delete_own') then
    create policy contact_person_group_links_delete_own on public.contact_person_group_links for delete using (auth.uid() = user_id);
  end if;
end $$;

-- custom_categories
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'custom_categories' and policyname = 'custom_categories_select_own') then
    create policy custom_categories_select_own on public.custom_categories for select using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'custom_categories' and policyname = 'custom_categories_insert_own') then
    create policy custom_categories_insert_own on public.custom_categories for insert with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'custom_categories' and policyname = 'custom_categories_update_own') then
    create policy custom_categories_update_own on public.custom_categories for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'custom_categories' and policyname = 'custom_categories_delete_own') then
    create policy custom_categories_delete_own on public.custom_categories for delete using (auth.uid() = user_id);
  end if;
end $$;

-- saved_locations
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'saved_locations' and policyname = 'saved_locations_select_own') then
    create policy saved_locations_select_own on public.saved_locations for select using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'saved_locations' and policyname = 'saved_locations_insert_own') then
    create policy saved_locations_insert_own on public.saved_locations for insert with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'saved_locations' and policyname = 'saved_locations_update_own') then
    create policy saved_locations_update_own on public.saved_locations for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where tablename = 'saved_locations' and policyname = 'saved_locations_delete_own') then
    create policy saved_locations_delete_own on public.saved_locations for delete using (auth.uid() = user_id);
  end if;
end $$;
