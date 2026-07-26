-- Security hardening (Chris Gervais / Jeff Pastorius feedback, July 2026):
-- 1) Repository & workshop documents: only the uploader or staff may update/delete
-- 2) Resource folders: only the creator or staff may rename/delete
--    (reverts open "any authenticated user" folder policies from jury cleanup)

-- Knowledge repository documents
DROP POLICY IF EXISTS "knowledge_repo_delete_own" ON public.knowledge_repository_documents;
DROP POLICY IF EXISTS knowledge_repo_delete_own ON public.knowledge_repository_documents;
DROP POLICY IF EXISTS knowledge_repo_staff_delete ON public.knowledge_repository_documents;
DROP POLICY IF EXISTS knowledge_repo_delete_owner_or_staff ON public.knowledge_repository_documents;

CREATE POLICY knowledge_repo_delete_owner_or_staff
  ON public.knowledge_repository_documents
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id
    OR public.dashboard_is_staff()
  );

DROP POLICY IF EXISTS knowledge_repo_update_own ON public.knowledge_repository_documents;
DROP POLICY IF EXISTS knowledge_repo_staff_update ON public.knowledge_repository_documents;
DROP POLICY IF EXISTS knowledge_repo_update_owner_or_staff ON public.knowledge_repository_documents;

CREATE POLICY knowledge_repo_update_owner_or_staff
  ON public.knowledge_repository_documents
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = user_id
    OR public.dashboard_is_staff()
  )
  WITH CHECK (
    auth.uid() = user_id
    OR public.dashboard_is_staff()
  );

-- Workshop documents
DROP POLICY IF EXISTS "workshop_docs_delete_own" ON public.workshop_documents;
DROP POLICY IF EXISTS workshop_docs_delete_own ON public.workshop_documents;
DROP POLICY IF EXISTS workshop_docs_staff_delete ON public.workshop_documents;
DROP POLICY IF EXISTS workshop_docs_delete_owner_or_staff ON public.workshop_documents;

CREATE POLICY workshop_docs_delete_owner_or_staff
  ON public.workshop_documents
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id
    OR public.dashboard_is_staff()
  );

DROP POLICY IF EXISTS workshop_docs_update_own ON public.workshop_documents;
DROP POLICY IF EXISTS workshop_docs_staff_update ON public.workshop_documents;
DROP POLICY IF EXISTS workshop_docs_update_owner_or_staff ON public.workshop_documents;

CREATE POLICY workshop_docs_update_owner_or_staff
  ON public.workshop_documents
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = user_id
    OR public.dashboard_is_staff()
  )
  WITH CHECK (
    auth.uid() = user_id
    OR public.dashboard_is_staff()
  );

-- Shared folders: create stays open to members; rename/delete = creator or staff only
DROP POLICY IF EXISTS "resource_folders_update_own" ON public.resource_folders;
DROP POLICY IF EXISTS "resource_folders_delete_own" ON public.resource_folders;
DROP POLICY IF EXISTS "resource_folders_update_authenticated" ON public.resource_folders;
DROP POLICY IF EXISTS "resource_folders_delete_authenticated" ON public.resource_folders;
DROP POLICY IF EXISTS resource_folders_update_creator_or_staff ON public.resource_folders;
DROP POLICY IF EXISTS resource_folders_delete_creator_or_staff ON public.resource_folders;

CREATE POLICY resource_folders_update_creator_or_staff
  ON public.resource_folders
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = created_by
    OR public.dashboard_is_staff()
  )
  WITH CHECK (
    auth.uid() = created_by
    OR public.dashboard_is_staff()
  );

CREATE POLICY resource_folders_delete_creator_or_staff
  ON public.resource_folders
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = created_by
    OR public.dashboard_is_staff()
  );

COMMENT ON POLICY knowledge_repo_delete_owner_or_staff ON public.knowledge_repository_documents IS
  'Members may delete only their own uploads; staff may delete any.';
COMMENT ON POLICY workshop_docs_delete_owner_or_staff ON public.workshop_documents IS
  'Members may delete only their own uploads; staff may delete any.';
COMMENT ON POLICY resource_folders_delete_creator_or_staff ON public.resource_folders IS
  'Members may delete folders they created; staff may delete any (including seeded folders).';
