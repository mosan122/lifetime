-- Enlaces hito ↔ personas etiquetadas (reemplazo completo por milestone_id en sync).

create table if not exists public.milestone_person_links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  milestone_id uuid not null,
  person_client_id text not null,
  is_protagonist boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, milestone_id, person_client_id)
);

create index if not exists milestone_person_links_milestone_id_idx
  on public.milestone_person_links (user_id, milestone_id);

alter table public.milestone_person_links enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'milestone_person_links'
      and policyname = 'milestone_person_links_select_own'
  ) then
    create policy milestone_person_links_select_own on public.milestone_person_links
      for select using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'milestone_person_links'
      and policyname = 'milestone_person_links_insert_own'
  ) then
    create policy milestone_person_links_insert_own on public.milestone_person_links
      for insert with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'milestone_person_links'
      and policyname = 'milestone_person_links_delete_own'
  ) then
    create policy milestone_person_links_delete_own on public.milestone_person_links
      for delete using (auth.uid() = user_id);
  end if;
end $$;
