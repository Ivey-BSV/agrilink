
BEGIN;

WITH stripped AS (
  SELECT
    p.id,
    p.created_at,
    btrim(
      regexp_replace(p.username, '_[0-9a-f]{32}$', '', 'i')
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
  FROM stripped
),
final AS (
  SELECT
    id,
    CASE
      WHEN btrim(COALESCE(base_name, '')) = '' THEN
        'user_' || replace(id::text, '-', '')
      WHEN cnt = 1 THEN btrim(base_name)
      WHEN rn = 1 THEN btrim(base_name)
      ELSE btrim(base_name) || '_' || rn::text
    END AS new_username
  FROM ranked
)
UPDATE public.user_profiles u
SET username = f.new_username
FROM final f
WHERE u.id = f.id;

COMMIT;
