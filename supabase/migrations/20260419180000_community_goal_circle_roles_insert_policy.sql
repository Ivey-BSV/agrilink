
DROP POLICY IF EXISTS circle_roles_creator_insert ON public.community_goal_circle_roles;

CREATE POLICY circle_roles_creator_insert
  ON public.community_goal_circle_roles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    community_goal_circle_roles.user_id IS NULL
    AND EXISTS (
      SELECT 1
      FROM public.goals g
      WHERE g.id = community_goal_circle_roles.goal_id
        AND g.user_id = auth.uid()
        AND lower(coalesce(g.goal_type, '')) = 'community'
    )
  );
