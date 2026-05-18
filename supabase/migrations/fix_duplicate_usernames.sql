
WITH ranked AS (
  SELECT
    id,
    username,
    created_at,
    ROW_NUMBER() OVER (
      PARTITION BY LOWER(TRIM(username))
      ORDER BY created_at ASC
    ) AS rn
  FROM public.user_profiles
  WHERE username IS NOT NULL AND TRIM(username) != ''
),
dupe_groups AS (
  SELECT LOWER(TRIM(username)) AS uname
  FROM public.user_profiles
  WHERE username IS NOT NULL AND TRIM(username) != ''
  GROUP BY LOWER(TRIM(username))
  HAVING COUNT(*) > 1
),
ids_to_update AS (
  SELECT r.id
  FROM ranked r
  JOIN dupe_groups d ON LOWER(TRIM(r.username)) = d.uname
  WHERE r.rn > 1
)
UPDATE public.user_profiles
SET username = TRIM(username) || '1'
WHERE id IN (SELECT id FROM ids_to_update);
