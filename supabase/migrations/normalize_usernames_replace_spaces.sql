
BEGIN;

WITH base AS (
  SELECT
    p.id,
    p.created_at,
    CASE
      WHEN p.username IS NULL OR btrim(p.username::text) = '' THEN ''
      ELSE regexp_replace(
        regexp_replace(
          regexp_replace(lower(btrim(p.username::text)), '\s+', '_', 'g'),
          '_+',
          '_',
          'g'
        ),
        '^_+|_+$',
        '',
        'g'
      )
    END AS normalized
  FROM public.user_profiles p
),
ranked_nonempty AS (
  SELECT
    id,
    created_at,
    normalized,
    ROW_NUMBER() OVER (
      PARTITION BY normalized
      ORDER BY created_at ASC NULLS LAST, id ASC
    ) AS rn,
    COUNT(*) OVER (PARTITION BY normalized) AS cnt
  FROM base
  WHERE normalized <> ''
),
ranked_empty AS (
  SELECT
    id,
    created_at,
    ROW_NUMBER() OVER (
      ORDER BY created_at ASC NULLS LAST, id ASC
    ) AS rn,
    COUNT(*) OVER () AS cnt
  FROM base
  WHERE normalized = ''
),
final AS (
  SELECT
    id,
    CASE
      WHEN cnt = 1 THEN normalized
      WHEN rn = 1 THEN normalized
      ELSE normalized || '_' || rn::text
    END AS new_username
  FROM ranked_nonempty
  UNION ALL
  SELECT
    id,
    CASE
      WHEN cnt = 1 THEN 'user'
      WHEN rn = 1 THEN 'user'
      ELSE 'user_' || rn::text
    END AS new_username
  FROM ranked_empty
)
UPDATE public.user_profiles u
SET username = f.new_username
FROM final f
WHERE u.id = f.id;

COMMIT;
