
CREATE TABLE IF NOT EXISTS public.workshop_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workshop_id text NOT NULL,
  user_id uuid NOT NULL REFERENCES public.user_profiles (id) ON DELETE CASCADE,
  title text NOT NULL,
  file_name text NOT NULL,
  file_url text NOT NULL,
  mime_type text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_workshop_documents_workshop
  ON public.workshop_documents (workshop_id, created_at DESC);

ALTER TABLE public.workshop_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "workshop_docs_select_authenticated"
  ON public.workshop_documents
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "workshop_docs_insert_own"
  ON public.workshop_documents
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "workshop_docs_delete_own"
  ON public.workshop_documents
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

INSERT INTO storage.buckets (id, name, public)
VALUES ('workshop-repository', 'workshop-repository', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "workshop_repo_storage_select"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'workshop-repository');

CREATE POLICY "workshop_repo_storage_insert"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'workshop-repository'
    AND split_part(name, '/', 2) = auth.uid()::text
  );

CREATE POLICY "workshop_repo_storage_delete_own"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'workshop-repository'
    AND split_part(name, '/', 2) = auth.uid()::text
  );
