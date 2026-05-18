
BEGIN;

WITH base AS (
  SELECT
    p.id,
    p.created_at,
    btrim(
      regexp_replace(
        regexp_replace(replace(lower(p.username), '@', '_'), '_+', '_', 'g'),
        '^_+|_+$',
        '',
        'g'
      )
    ) AS base_name
  FROM public.user_profiles p
),
ranked AS (
  SELECT
    id,
    created_at,
    base_name,
    ROW_NUMBER() OVER (
      PARTITION BY base_name
      ORDER BY created_at ASC NULLS LAST, id ASC
    ) AS rn,
    COUNT(*) OVER (PARTITION BY base_name) AS cnt
  FROM base
),
final AS (
  SELECT
    id,
    CASE
      WHEN btrim(COALESCE(base_name, '')) = '' THEN
        'user_' || replace(id::text, '-', '')
      WHEN cnt = 1 THEN base_name
      WHEN rn = 1 THEN base_name
      ELSE base_name || '_' || rn::text
    END AS new_username
  FROM ranked
)
UPDATE public.user_profiles u
SET username = f.new_username
FROM final f
WHERE u.id = f.id;

COMMIT;
