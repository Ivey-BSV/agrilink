CREATE OR REPLACE FUNCTION public.user_profiles_guard_privileged_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF current_setting('request.jwt.claim.role', true) = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NOT public.dashboard_is_staff() THEN
      NEW.account_kind := 'farmer';
      NEW.app_role := 'end_user';
      IF NEW.registration_status IS NULL
          OR NEW.registration_status NOT IN ('pending', 'active') THEN
        NEW.registration_status := 'active';
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NOT public.dashboard_is_staff() THEN
      NEW.account_kind := OLD.account_kind;
      NEW.app_role := OLD.app_role;
      NEW.registration_status := OLD.registration_status;
      NEW.access_tier := OLD.access_tier;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_user_profiles_guard_privileged ON public.user_profiles;
CREATE TRIGGER trg_user_profiles_guard_privileged
  BEFORE INSERT OR UPDATE ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.user_profiles_guard_privileged_columns();

DROP POLICY IF EXISTS "messages_update_in_my_chats_v3" ON public.messages;
CREATE POLICY "messages_update_in_my_chats_v3"
  ON public.messages FOR UPDATE
  USING (
    auth.uid() IS NOT NULL
    AND sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.chats c
      WHERE c.id = messages.chat_id
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.chats c
      WHERE c.id = messages.chat_id
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS app_settings_select_authenticated ON public.app_settings;
CREATE POLICY app_settings_select_staff
  ON public.app_settings FOR SELECT TO authenticated
  USING (public.dashboard_is_staff());

DROP POLICY IF EXISTS "knowledge_repo_insert_own" ON public.knowledge_repository_documents;
CREATE POLICY knowledge_repo_insert_own
  ON public.knowledge_repository_documents FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND (
      public.dashboard_is_staff()
      OR approval_status = 'pending'
    )
  );

DROP POLICY IF EXISTS knowledge_repo_update_own ON public.knowledge_repository_documents;
CREATE POLICY knowledge_repo_update_own
  ON public.knowledge_repository_documents FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND (
      public.dashboard_is_staff()
      OR approval_status = OLD.approval_status
    )
  );

DROP POLICY IF EXISTS goal_docs_insert_when_can_contribute ON public.goal_documents;
CREATE POLICY goal_docs_insert_when_can_contribute
  ON public.goal_documents FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND (
      public.dashboard_is_staff()
      OR approval_status = 'pending'
    )
    AND EXISTS (
      SELECT 1
      FROM public.goals g
      WHERE g.id = goal_documents.goal_id
        AND (
          (g.goal_type = 'personal' AND g.user_id = auth.uid())
          OR (
            g.goal_type = 'community'
            AND (
              g.user_id = auth.uid()
              OR EXISTS (
                SELECT 1
                FROM public.community_goal_participants cgp
                WHERE cgp.goal_id = g.id AND cgp.user_id = auth.uid()
              )
            )
          )
        )
    )
  );
