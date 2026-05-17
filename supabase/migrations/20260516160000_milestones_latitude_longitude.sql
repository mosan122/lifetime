-- Coordenadas sin PostGIS (la app ya no usa location_coords en sync).
ALTER TABLE public.milestones
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision;
