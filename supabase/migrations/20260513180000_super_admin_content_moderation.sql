
DROP POLICY IF EXISTS polls_super_admin_insert ON public.polls;
CREATE POLICY polls_super_admin_insert
  ON public.polls FOR INSERT TO authenticated
  WITH CHECK (public.dashboard_is_super_admin());

DROP POLICY IF EXISTS polls_super_admin_update ON public.polls;
CREATE POLICY polls_super_admin_update
  ON public.polls FOR UPDATE TO authenticated
  USING (public.dashboard_is_super_admin())
  WITH CHECK (public.dashboard_is_super_admin());

DROP POLICY IF EXISTS polls_super_admin_delete ON public.polls;
CREATE POLICY polls_super_admin_delete
  ON public.polls FOR DELETE TO authenticated
  USING (public.dashboard_is_super_admin());

DROP POLICY IF EXISTS poll_options_super_admin_insert ON public.poll_options;
CREATE POLICY poll_options_super_admin_insert
  ON public.poll_options FOR INSERT TO authenticated
  WITH CHECK (public.dashboard_is_super_admin());

DROP POLICY IF EXISTS poll_options_super_admin_update ON public.poll_options;
CREATE POLICY poll_options_super_admin_update
  ON public.poll_options FOR UPDATE TO authenticated
  USING (public.dashboard_is_super_admin())
  WITH CHECK (public.dashboard_is_super_admin());

DROP POLICY IF EXISTS poll_options_super_admin_delete ON public.poll_options;
CREATE POLICY poll_options_super_admin_delete
  ON public.poll_options FOR DELETE TO authenticated
  USING (public.dashboard_is_super_admin());

DROP POLICY IF EXISTS poll_votes_super_admin_delete ON public.poll_votes;
CREATE POLICY poll_votes_super_admin_delete
  ON public.poll_votes FOR DELETE TO authenticated
  USING (public.dashboard_is_super_admin());

DO $moderation$
BEGIN
  IF to_regclass('public.posts') IS NOT NULL THEN
    EXECUTE $p$
      DROP POLICY IF EXISTS posts_super_admin_select ON public.posts;
      CREATE POLICY posts_super_admin_select
        ON public.posts FOR SELECT TO authenticated
        USING (public.dashboard_is_super_admin());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS posts_super_admin_insert ON public.posts;
      CREATE POLICY posts_super_admin_insert
        ON public.posts FOR INSERT TO authenticated
        WITH CHECK (public.dashboard_is_super_admin());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS posts_super_admin_update ON public.posts;
      CREATE POLICY posts_super_admin_update
        ON public.posts FOR UPDATE TO authenticated
        USING (public.dashboard_is_super_admin())
        WITH CHECK (public.dashboard_is_super_admin());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS posts_super_admin_delete ON public.posts;
      CREATE POLICY posts_super_admin_delete
        ON public.posts FOR DELETE TO authenticated
        USING (public.dashboard_is_super_admin());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS posts_update_own ON public.posts;
      CREATE POLICY posts_update_own
        ON public.posts FOR UPDATE TO authenticated
        USING (user_id = auth.uid())
        WITH CHECK (user_id = auth.uid());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS posts_delete_own ON public.posts;
      CREATE POLICY posts_delete_own
        ON public.posts FOR DELETE TO authenticated
        USING (user_id = auth.uid());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS posts_insert_own ON public.posts;
      CREATE POLICY posts_insert_own
        ON public.posts FOR INSERT TO authenticated
        WITH CHECK (user_id = auth.uid());
    $p$;
  END IF;

  IF to_regclass('public.comments') IS NOT NULL THEN
    EXECUTE $p$
      DROP POLICY IF EXISTS comments_super_admin_select ON public.comments;
      CREATE POLICY comments_super_admin_select
        ON public.comments FOR SELECT TO authenticated
        USING (public.dashboard_is_super_admin());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS comments_super_admin_insert ON public.comments;
      CREATE POLICY comments_super_admin_insert
        ON public.comments FOR INSERT TO authenticated
        WITH CHECK (public.dashboard_is_super_admin());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS comments_super_admin_update ON public.comments;
      CREATE POLICY comments_super_admin_update
        ON public.comments FOR UPDATE TO authenticated
        USING (public.dashboard_is_super_admin())
        WITH CHECK (public.dashboard_is_super_admin());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS comments_super_admin_delete ON public.comments;
      CREATE POLICY comments_super_admin_delete
        ON public.comments FOR DELETE TO authenticated
        USING (public.dashboard_is_super_admin());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS comments_delete_own ON public.comments;
      CREATE POLICY comments_delete_own
        ON public.comments FOR DELETE TO authenticated
        USING (user_id = auth.uid());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS comments_update_own ON public.comments;
      CREATE POLICY comments_update_own
        ON public.comments FOR UPDATE TO authenticated
        USING (user_id = auth.uid())
        WITH CHECK (user_id = auth.uid());
    $p$;
  END IF;
END
$moderation$;

DO $goals_mod$
BEGIN
  IF to_regclass('public.goals') IS NOT NULL THEN
    EXECUTE $p$
      DROP POLICY IF EXISTS goals_super_admin_all ON public.goals;
      CREATE POLICY goals_super_admin_all
        ON public.goals FOR ALL TO authenticated
        USING (public.dashboard_is_super_admin())
        WITH CHECK (public.dashboard_is_super_admin());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS goals_insert_author ON public.goals;
      CREATE POLICY goals_insert_author
        ON public.goals FOR INSERT TO authenticated
        WITH CHECK (user_id = auth.uid());
    $p$;
  END IF;

  IF to_regclass('public.goal_milestones') IS NOT NULL THEN
    EXECUTE $p$
      DROP POLICY IF EXISTS goal_milestones_super_admin_all ON public.goal_milestones;
      CREATE POLICY goal_milestones_super_admin_all
        ON public.goal_milestones FOR ALL TO authenticated
        USING (public.dashboard_is_super_admin())
        WITH CHECK (public.dashboard_is_super_admin());
    $p$;
  END IF;

  IF to_regclass('public.community_goal_participants') IS NOT NULL THEN
    EXECUTE $p$
      DROP POLICY IF EXISTS community_goal_participants_super_admin_all ON public.community_goal_participants;
      CREATE POLICY community_goal_participants_super_admin_all
        ON public.community_goal_participants FOR ALL TO authenticated
        USING (public.dashboard_is_super_admin())
        WITH CHECK (public.dashboard_is_super_admin());
    $p$;
  END IF;

  IF to_regclass('public.community_goal_circle_roles') IS NOT NULL THEN
    EXECUTE $p$
      DROP POLICY IF EXISTS community_goal_circle_roles_super_admin_all ON public.community_goal_circle_roles;
      CREATE POLICY community_goal_circle_roles_super_admin_all
        ON public.community_goal_circle_roles FOR ALL TO authenticated
        USING (public.dashboard_is_super_admin())
        WITH CHECK (public.dashboard_is_super_admin());
    $p$;
  END IF;
END
$goals_mod$;

DO $events_mod$
BEGIN
  IF to_regclass('public.events') IS NOT NULL THEN
    EXECUTE $p$
      DROP POLICY IF EXISTS events_insert_owner ON public.events;
      CREATE POLICY events_insert_owner
        ON public.events FOR INSERT TO authenticated
        WITH CHECK (user_id = auth.uid());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS events_update_owner ON public.events;
      CREATE POLICY events_update_owner
        ON public.events FOR UPDATE TO authenticated
        USING (user_id = auth.uid())
        WITH CHECK (user_id = auth.uid());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS events_delete_owner ON public.events;
      CREATE POLICY events_delete_owner
        ON public.events FOR DELETE TO authenticated
        USING (user_id = auth.uid());
    $p$;
  END IF;

  IF to_regclass('public.event_registrations') IS NOT NULL THEN
    EXECUTE $p$
      DROP POLICY IF EXISTS event_registrations_insert_self ON public.event_registrations;
      CREATE POLICY event_registrations_insert_self
        ON public.event_registrations FOR INSERT TO authenticated
        WITH CHECK (user_id = auth.uid());
    $p$;
    EXECUTE $p$
      DROP POLICY IF EXISTS event_registrations_delete_self ON public.event_registrations;
      CREATE POLICY event_registrations_delete_self
        ON public.event_registrations FOR DELETE TO authenticated
        USING (user_id = auth.uid());
    $p$;
  END IF;
END
$events_mod$;
