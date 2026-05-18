
CREATE TABLE IF NOT EXISTS public.polls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by uuid NOT NULL REFERENCES public.user_profiles (id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  allows_multiple boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'active'::text
    CHECK (status = ANY (ARRAY['active'::text, 'closed'::text])),
  closes_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS polls_created_at_idx ON public.polls (created_at DESC);
CREATE INDEX IF NOT EXISTS polls_status_idx ON public.polls (status);

CREATE TABLE IF NOT EXISTS public.poll_options (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id uuid NOT NULL REFERENCES public.polls (id) ON DELETE CASCADE,
  label text NOT NULL,
  position smallint NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS poll_options_poll_id_idx ON public.poll_options (poll_id);

CREATE TABLE IF NOT EXISTS public.poll_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id uuid NOT NULL REFERENCES public.polls (id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.user_profiles (id) ON DELETE CASCADE,
  option_id uuid NOT NULL REFERENCES public.poll_options (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT poll_votes_poll_user_option_key UNIQUE (poll_id, user_id, option_id)
);

CREATE INDEX IF NOT EXISTS poll_votes_poll_id_idx ON public.poll_votes (poll_id);

CREATE OR REPLACE FUNCTION public.touch_polls_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_polls_updated_at ON public.polls;
CREATE TRIGGER trg_polls_updated_at
  BEFORE UPDATE ON public.polls
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_polls_updated_at();

ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS polls_select_auth ON public.polls;
CREATE POLICY polls_select_auth
  ON public.polls FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS polls_insert_own ON public.polls;
CREATE POLICY polls_insert_own
  ON public.polls FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid());

DROP POLICY IF EXISTS polls_update_creator ON public.polls;
CREATE POLICY polls_update_creator
  ON public.polls FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

DROP POLICY IF EXISTS polls_delete_creator ON public.polls;
CREATE POLICY polls_delete_creator
  ON public.polls FOR DELETE
  TO authenticated
  USING (created_by = auth.uid());

DROP POLICY IF EXISTS poll_options_select_auth ON public.poll_options;
CREATE POLICY poll_options_select_auth
  ON public.poll_options FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS poll_options_insert_creator ON public.poll_options;
CREATE POLICY poll_options_insert_creator
  ON public.poll_options FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.polls p
      WHERE p.id = poll_options.poll_id AND p.created_by = auth.uid()
    )
  );

DROP POLICY IF EXISTS poll_options_delete_creator ON public.poll_options;
CREATE POLICY poll_options_delete_creator
  ON public.poll_options FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.polls p
      WHERE p.id = poll_options.poll_id AND p.created_by = auth.uid()
    )
  );

DROP POLICY IF EXISTS poll_votes_select_auth ON public.poll_votes;
CREATE POLICY poll_votes_select_auth
  ON public.poll_votes FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS poll_votes_insert_own ON public.poll_votes;
CREATE POLICY poll_votes_insert_own
  ON public.poll_votes FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.polls p
      WHERE p.id = poll_votes.poll_id
        AND p.status = 'active'::text
        AND (p.closes_at IS NULL OR p.closes_at > now())
    )
  );

DROP POLICY IF EXISTS poll_votes_delete_own ON public.poll_votes;
CREATE POLICY poll_votes_delete_own
  ON public.poll_votes FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

COMMENT ON TABLE public.polls IS 'Cohort-wide polls; allows_multiple controls multi-select voting.';
COMMENT ON TABLE public.poll_votes IS 'One row per user per selected option; single-select replaces via app deletes.';
