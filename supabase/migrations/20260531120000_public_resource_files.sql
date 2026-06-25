-- Workshop + repository files: visible to all signed-in users, no approval gate.

DROP POLICY IF EXISTS knowledge_repo_select_visible ON public.knowledge_repository_documents;
CREATE POLICY knowledge_repo_select_visible
  ON public.knowledge_repository_documents FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "knowledge_repo_insert_own" ON public.knowledge_repository_documents;
CREATE POLICY knowledge_repo_insert_own
  ON public.knowledge_repository_documents FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Publish anything still marked pending (legacy uploads)
UPDATE public.knowledge_repository_documents
SET approval_status = 'approved'
WHERE approval_status = 'pending';

UPDATE public.workshop_documents
SET approval_status = 'approved'
WHERE approval_status = 'pending';
