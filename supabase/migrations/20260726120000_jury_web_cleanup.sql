-- Jury web cleanup (July 2026):
-- 1) Remove obsolete "General" repository folder (materials moved elsewhere)
-- 2) Remove test poll "Have you seen this list before"
-- 3) Hide unrecognized / test accounts from the farm directory
-- 4) Allow any signed-in member to rename/delete shared resource folders
--    (knowledge sharing is collaborative; seeded folders have created_by NULL)

-- 1) General folder + its documents
DELETE FROM public.knowledge_repository_documents
WHERE folder_id IN (
  SELECT id FROM public.resource_folders
  WHERE scope = 'repository' AND lower(trim(name)) = 'general'
);

DELETE FROM public.resource_folders
WHERE scope = 'repository' AND lower(trim(name)) = 'general';

-- 2) Test poll (options/votes cascade)
DELETE FROM public.polls
WHERE lower(trim(title)) = lower(trim('Have you seen this list before'));

-- 3) Farm directory: keep profiles, but stop listing them as farmers
UPDATE public.user_profiles
SET account_kind = 'staff'
WHERE
  lower(replace(coalesce(username, ''), ' ', '')) IN (
    'mira123',
    'dustismall',
    'johndoe123',
    'amberhilstrom',
    'billherring'
  )
  OR lower(coalesce(full_name, '')) IN (
    'scott zhu consensus',
    'amy frankel417',
    'amber hilstrom',
    'bill herring'
  )
  OR lower(coalesce(username, '')) IN (
    'amberhilstrom',
    'billherring',
    'mira123',
    'dustismall',
    'johndoe123'
  )
  OR lower(coalesce(full_name, '')) LIKE 'amy frankel%'
  OR lower(coalesce(full_name, '')) LIKE 'scott zhu%';

-- 4) Shared folder management for non-tech members
DROP POLICY IF EXISTS "resource_folders_update_own" ON public.resource_folders;
DROP POLICY IF EXISTS "resource_folders_delete_own" ON public.resource_folders;
DROP POLICY IF EXISTS "resource_folders_update_authenticated" ON public.resource_folders;
DROP POLICY IF EXISTS "resource_folders_delete_authenticated" ON public.resource_folders;

CREATE POLICY "resource_folders_update_authenticated"
  ON public.resource_folders
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "resource_folders_delete_authenticated"
  ON public.resource_folders
  FOR DELETE
  TO authenticated
  USING (true);
