
CREATE TABLE IF NOT EXISTS public.goal_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id uuid NOT NULL REFERENCES public.goals (id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.user_profiles (id) ON DELETE CASCADE,
  title text NOT NULL,
  file_name text NOT NULL,
  file_url text NOT NULL,
  mime_type text,
  created_at timestamptz NOT NULL DEFAULT now(),
  approval_status text NOT NULL DEFAULT 'approved',
  visibility_rules jsonb NOT NULL DEFAULT '{}'::jsonb,
  consent_agreed_at timestamptz,
  reviewed_by uuid REFERENCES public.user_profiles (id),
  reviewed_at timestamptz,
  CONSTRAINT goal_documents_approval_status_check
    CHECK (approval_status IN ('pending', 'approved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS idx_goal_documents_goal_created
  ON public.goal_documents (goal_id, created_at DESC);

ALTER TABLE public.goal_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS goal_docs_select_authenticated ON public.goal_documents;
CREATE POLICY goal_docs_select_authenticated
  ON public.goal_documents
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS goal_docs_staff_select_all ON public.goal_documents;
CREATE POLICY goal_docs_staff_select_all
  ON public.goal_documents
  FOR SELECT
  TO authenticated
  USING (public.dashboard_is_staff());

DROP POLICY IF EXISTS goal_docs_insert_when_can_contribute ON public.goal_documents;
CREATE POLICY goal_docs_insert_when_can_contribute
  ON public.goal_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
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
                FROM public.community_goal_participants p
                WHERE p.goal_id = g.id
                  AND p.user_id = auth.uid()
              )
            )
          )
        )
    )
  );

DROP POLICY IF EXISTS goal_docs_delete_own ON public.goal_documents;
CREATE POLICY goal_docs_delete_own
  ON public.goal_documents
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS goal_docs_staff_delete ON public.goal_documents;
CREATE POLICY goal_docs_staff_delete
  ON public.goal_documents
  FOR DELETE
  TO authenticated
  USING (public.dashboard_is_staff());

DROP POLICY IF EXISTS goal_docs_staff_update ON public.goal_documents;
CREATE POLICY goal_docs_staff_update
  ON public.goal_documents
  FOR UPDATE
  TO authenticated
  USING (public.dashboard_is_staff())
  WITH CHECK (true);

INSERT INTO storage.buckets (id, name, public)
VALUES ('goal-repository', 'goal-repository', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS goal_repo_storage_select ON storage.objects;
CREATE POLICY goal_repo_storage_select
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'goal-repository');

DROP POLICY IF EXISTS goal_repo_storage_insert ON storage.objects;
CREATE POLICY goal_repo_storage_insert
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'goal-repository'
    AND split_part(name, '/', 2) = auth.uid()::text
  );

DROP POLICY IF EXISTS goal_repo_storage_delete_own ON storage.objects;
CREATE POLICY goal_repo_storage_delete_own
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'goal-repository'
    AND split_part(name, '/', 2) = auth.uid()::text
  );
