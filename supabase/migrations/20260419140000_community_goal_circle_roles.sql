
CREATE TABLE IF NOT EXISTS public.community_goal_circle_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id uuid NOT NULL REFERENCES public.goals (id) ON DELETE CASCADE,
  role text NOT NULL CHECK (
    role = ANY (
      ARRAY['leader', 'secretary', 'delegate', 'facilitator']::text[]
    )
  ),
  user_id uuid REFERENCES public.user_profiles (id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT community_goal_circle_roles_goal_id_role_key UNIQUE (goal_id, role)
);

CREATE INDEX IF NOT EXISTS community_goal_circle_roles_goal_id_idx
  ON public.community_goal_circle_roles (goal_id);

COMMENT ON TABLE public.community_goal_circle_roles IS
  'Four governing seats per community goal; creator assigns, members may claim vacant seats.';

CREATE OR REPLACE FUNCTION public.touch_community_goal_circle_roles_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_community_goal_circle_roles_updated_at
  ON public.community_goal_circle_roles;

CREATE TRIGGER trg_community_goal_circle_roles_updated_at
  BEFORE UPDATE ON public.community_goal_circle_roles
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_community_goal_circle_roles_updated_at();

CREATE OR REPLACE FUNCTION public.seed_community_goal_circle_roles()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF lower(coalesce(NEW.goal_type, '')) = 'community' THEN
    INSERT INTO public.community_goal_circle_roles (goal_id, role)
    VALUES
      (NEW.id, 'leader'),
      (NEW.id, 'secretary'),
      (NEW.id, 'delegate'),
      (NEW.id, 'facilitator')
    ON CONFLICT (goal_id, role) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_goals_seed_circle_roles ON public.goals;

CREATE TRIGGER trg_goals_seed_circle_roles
  AFTER INSERT ON public.goals
  FOR EACH ROW
  EXECUTE FUNCTION public.seed_community_goal_circle_roles();

INSERT INTO public.community_goal_circle_roles (goal_id, role)
SELECT g.id, r.role
FROM public.goals g
CROSS JOIN (
  VALUES
    ('leader'),
    ('secretary'),
    ('delegate'),
    ('facilitator')
) AS r (role)
WHERE lower(coalesce(g.goal_type, '')) = 'community'
ON CONFLICT (goal_id, role) DO NOTHING;

ALTER TABLE public.community_goal_circle_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS circle_roles_select_auth ON public.community_goal_circle_roles;
CREATE POLICY circle_roles_select_auth
  ON public.community_goal_circle_roles
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS circle_roles_creator_update ON public.community_goal_circle_roles;
CREATE POLICY circle_roles_creator_update
  ON public.community_goal_circle_roles
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.goals g
      WHERE g.id = community_goal_circle_roles.goal_id
        AND g.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.goals g
      WHERE g.id = community_goal_circle_roles.goal_id
        AND g.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS circle_roles_participant_claim ON public.community_goal_circle_roles;
CREATE POLICY circle_roles_participant_claim
  ON public.community_goal_circle_roles
  FOR UPDATE
  TO authenticated
  USING (
    community_goal_circle_roles.user_id IS NULL
    AND EXISTS (
      SELECT 1
      FROM public.community_goal_participants p
      WHERE p.goal_id = community_goal_circle_roles.goal_id
        AND p.user_id = auth.uid()
    )
  )
  WITH CHECK (
    community_goal_circle_roles.user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.community_goal_participants p
      WHERE p.goal_id = community_goal_circle_roles.goal_id
        AND p.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS circle_roles_holder_release ON public.community_goal_circle_roles;
CREATE POLICY circle_roles_holder_release
  ON public.community_goal_circle_roles
  FOR UPDATE
  TO authenticated
  USING (community_goal_circle_roles.user_id = auth.uid())
  WITH CHECK (community_goal_circle_roles.user_id IS NULL);
