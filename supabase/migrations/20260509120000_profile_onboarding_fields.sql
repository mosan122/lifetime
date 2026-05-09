-- Campos de perfil / onboarding (idempotente).

alter table public.profiles
  add column if not exists display_name text;

alter table public.profiles
  add column if not exists first_name text;

alter table public.profiles
  add column if not exists last_name text;

alter table public.profiles
  add column if not exists birth_date date;

alter table public.profiles
  add column if not exists last_connection timestamptz;
