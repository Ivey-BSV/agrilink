-- Poll votes: members see only their own rows; super admins see all.
-- Aggregated counts are exposed via get_poll_vote_counts() for everyone.

DROP POLICY IF EXISTS poll_votes_select_auth ON public.poll_votes;

CREATE POLICY poll_votes_select_own
  ON public.poll_votes FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY poll_votes_select_super_admin
  ON public.poll_votes FOR SELECT TO authenticated
  USING (public.dashboard_is_super_admin());

CREATE OR REPLACE FUNCTION public.get_poll_vote_counts(p_poll_id uuid)
RETURNS TABLE(option_id uuid, vote_count bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT pv.option_id, COUNT(*)::bigint
  FROM public.poll_votes pv
  WHERE pv.poll_id = p_poll_id
  GROUP BY pv.option_id;
$$;

REVOKE ALL ON FUNCTION public.get_poll_vote_counts(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_poll_vote_counts(uuid) TO authenticated;

COMMENT ON FUNCTION public.get_poll_vote_counts(uuid) IS
  'Per-option vote totals for a poll; does not expose voter identities.';
