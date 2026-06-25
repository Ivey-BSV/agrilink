-- Run this if 20260530120000_resource_folders.sql failed partway (policies already exist).
-- Safe to re-run.

DROP POLICY IF EXISTS "resource_folders_select_authenticated" ON public.resource_folders;
CREATE POLICY "resource_folders_select_authenticated"
  ON public.resource_folders FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "resource_folders_insert_authenticated" ON public.resource_folders;
CREATE POLICY "resource_folders_insert_authenticated"
  ON public.resource_folders FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = created_by);

DROP POLICY IF EXISTS "resource_folders_update_own" ON public.resource_folders;
CREATE POLICY "resource_folders_update_own"
  ON public.resource_folders FOR UPDATE TO authenticated
  USING (auth.uid() = created_by) WITH CHECK (auth.uid() = created_by);

DROP POLICY IF EXISTS "resource_folders_delete_own" ON public.resource_folders;
CREATE POLICY "resource_folders_delete_own"
  ON public.resource_folders FOR DELETE TO authenticated
  USING (auth.uid() = created_by);

ALTER TABLE public.workshop_documents
  ADD COLUMN IF NOT EXISTS folder_id uuid REFERENCES public.resource_folders (id) ON DELETE SET NULL;

ALTER TABLE public.knowledge_repository_documents
  ADD COLUMN IF NOT EXISTS folder_id uuid REFERENCES public.resource_folders (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_workshop_documents_folder
  ON public.workshop_documents (folder_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_knowledge_repo_folder
  ON public.knowledge_repository_documents (folder_id, created_at DESC);

ALTER TABLE public.workshop_documents
  ALTER COLUMN workshop_id DROP NOT NULL;

INSERT INTO public.resource_folders (scope, name, sort_order, legacy_workshop_id)
SELECT v.scope, v.name, v.sort_order, v.legacy_workshop_id
FROM (
  VALUES
    ('workshop', 'Social Event 1', 10, '1'),
    ('workshop', 'Workshop 1 — Connectivity and Reciprocity', 20, '2'),
    ('workshop', 'Workshop 2 — Learning Through Stories', 30, '3'),
    ('workshop', 'Workshop 3 — Systems Problems to Tackle Together', 40, '4'),
    ('workshop', 'Tentative Social Event #2 — Farm Bus Tour', 50, '5'),
    ('workshop', 'Workshop 4 — Toward Systems Solutions to Build Together', 60, '6'),
    ('workshop', 'Workshop 5 & Social Event 2 — Connectivity with Value Chain', 70, '7'),
    ('workshop', 'Workshop 6 — Strengthening Solutions', 80, '8'),
    ('workshop', 'Workshop 7 — Planning and Enabling Collective Action', 90, '9'),
    ('workshop', 'Workshops 8 & 9 — legacy uploads', 95, '10')
) AS v(scope, name, sort_order, legacy_workshop_id)
WHERE NOT EXISTS (
  SELECT 1 FROM public.resource_folders rf
  WHERE rf.scope = v.scope AND rf.legacy_workshop_id IS NOT DISTINCT FROM v.legacy_workshop_id
);

INSERT INTO public.resource_folders (scope, name, sort_order)
SELECT v.scope, v.name, v.sort_order
FROM (
  VALUES
    ('workshop', 'Workshop 8', 100),
    ('workshop', 'Workshop 9', 110),
    ('workshop', 'May 6 Open Lecture', 120),
    ('workshop', 'Virtual Meeting 1 (Workshop 10 — May 11)', 130),
    ('workshop', 'Virtual Meeting 2 (Workshop 11 — June 15)', 140),
    ('workshop', 'Bus Tour #2 (June 22)', 150),
    ('workshop', 'AgriLink Drop-in Session (June 29)', 160),
    ('workshop', 'Virtual Meeting 3 (Workshop 12 — July 13)', 170)
) AS v(scope, name, sort_order)
WHERE NOT EXISTS (
  SELECT 1 FROM public.resource_folders rf WHERE rf.scope = v.scope AND rf.name = v.name
);

INSERT INTO public.resource_folders (scope, name, sort_order)
SELECT 'repository', 'General', 0
WHERE NOT EXISTS (
  SELECT 1 FROM public.resource_folders WHERE scope = 'repository' AND name = 'General'
);

UPDATE public.workshop_documents wd
SET folder_id = rf.id
FROM public.resource_folders rf
WHERE wd.folder_id IS NULL
  AND rf.scope = 'workshop'
  AND rf.legacy_workshop_id IS NOT NULL
  AND rf.legacy_workshop_id = wd.workshop_id;

UPDATE public.knowledge_repository_documents kd
SET folder_id = rf.id
FROM public.resource_folders rf
WHERE kd.folder_id IS NULL
  AND rf.scope = 'repository'
  AND rf.name = 'General';

DROP POLICY IF EXISTS "knowledge_repo_storage_insert" ON storage.objects;
CREATE POLICY "knowledge_repo_storage_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'knowledge-repository'
    AND (
      split_part(name, '/', 1) = auth.uid()::text
      OR split_part(name, '/', 2) = auth.uid()::text
    )
  );

DROP POLICY IF EXISTS "knowledge_repo_storage_delete_own" ON storage.objects;
CREATE POLICY "knowledge_repo_storage_delete_own"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'knowledge-repository'
    AND (
      split_part(name, '/', 1) = auth.uid()::text
      OR split_part(name, '/', 2) = auth.uid()::text
    )
  );
