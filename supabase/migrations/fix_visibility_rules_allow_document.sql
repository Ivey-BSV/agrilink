
CREATE OR REPLACE FUNCTION public.visibility_rules_allow_document(rules jsonb, viewer_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
<<vis>>
DECLARE
  tiers jsonb;
  uids jsonb;
  viewer_tier text;
BEGIN
  IF rules IS NULL OR rules = '{}'::jsonb THEN
    RETURN true;
  END IF;

  uids := rules -> 'user_ids';
  IF uids IS NOT NULL AND jsonb_typeof(uids) = 'array' THEN
    IF EXISTS (
      SELECT 1
      FROM jsonb_array_elements_text(uids) AS uid_row(uid_txt)
      WHERE uid_row.uid_txt = viewer_id::text
    ) THEN
      RETURN true;
    END IF;
  END IF;

  tiers := rules -> 'tiers';
  IF tiers IS NULL OR jsonb_typeof(tiers) <> 'array' OR jsonb_array_length(tiers) = 0 THEN
    RETURN true;
  END IF;

  SELECT p.access_tier INTO viewer_tier
  FROM public.user_profiles AS p
  WHERE p.id = viewer_id;

  IF vis.viewer_tier IS NULL OR btrim(vis.viewer_tier) = '' THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM jsonb_array_elements_text(tiers) AS tier_row(tier_val)
    WHERE tier_val IS NOT NULL
      AND btrim(tier_val) <> ''
      AND tier_val = vis.viewer_tier
  );
END;
$$;
