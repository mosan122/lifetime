-- Flutter Color.value / colorArgb supera int4 (p. ej. 0xFF9575CD > 2_147_483_647).

ALTER TABLE public.custom_categories
  ALTER COLUMN color_value TYPE bigint USING color_value::bigint;

COMMENT ON COLUMN public.custom_categories.color_value IS
  'ARGB 32 bits (Flutter Color.value). bigint para valores > int4.';
