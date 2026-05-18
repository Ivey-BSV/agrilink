
CREATE TABLE IF NOT EXISTS public.knowledge_repository_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.user_profiles (id) ON DELETE CASCADE,
  title text NOT NULL,
  file_name text NOT NULL,
  file_url text NOT NULL,
  mime_type text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_knowledge_repo_created_at
  ON public.knowledge_repository_documents (created_at DESC);

ALTER TABLE public.knowledge_repository_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "knowledge_repo_select_authenticated"
  ON public.knowledge_repository_documents
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "knowledge_repo_insert_own"
  ON public.knowledge_repository_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "knowledge_repo_delete_own"
  ON public.knowledge_repository_documents
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

INSERT INTO storage.buckets (id, name, public)
VALUES ('knowledge-repository', 'knowledge-repository', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "knowledge_repo_storage_select"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'knowledge-repository');

CREATE POLICY "knowledge_repo_storage_insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'knowledge-repository'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

CREATE POLICY "knowledge_repo_storage_delete_own"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'knowledge-repository'
    AND split_part(name, '/', 1) = auth.uid()::text
  );
