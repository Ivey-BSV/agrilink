
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS account_kind text NOT NULL DEFAULT 'farmer',
  ADD COLUMN IF NOT EXISTS app_role text NOT NULL DEFAULT 'end_user',
  ADD COLUMN IF NOT EXISTS access_tier text,
  ADD COLUMN IF NOT EXISTS registration_status text NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS role text;

COMMENT ON COLUMN public.user_profiles.account_kind IS 'farmer | staff';
COMMENT ON COLUMN public.user_profiles.app_role IS 'end_user | moderator | admin | super_admin';
COMMENT ON COLUMN public.user_profiles.access_tier IS 'e.g. Phase 1 - Core Farmer; visibility tier for features/content';
COMMENT ON COLUMN public.user_profiles.registration_status IS 'pending | approved | denied | suspended | archived | active';

ALTER TABLE public.user_profiles
  DROP CONSTRAINT IF EXISTS user_profiles_account_kind_check;
ALTER TABLE public.user_profiles
  ADD CONSTRAINT user_profiles_account_kind_check
  CHECK (account_kind IN ('farmer', 'staff'));

ALTER TABLE public.user_profiles
  DROP CONSTRAINT IF EXISTS user_profiles_app_role_check;
ALTER TABLE public.user_profiles
  ADD CONSTRAINT user_profiles_app_role_check
  CHECK (app_role IN ('end_user', 'moderator', 'admin', 'super_admin'));

ALTER TABLE public.user_profiles
  DROP CONSTRAINT IF EXISTS user_profiles_registration_status_check;
ALTER TABLE public.user_profiles
  ADD CONSTRAINT user_profiles_registration_status_check
  CHECK (registration_status IN ('pending', 'approved', 'denied', 'suspended', 'archived', 'active'));

UPDATE public.user_profiles
SET app_role = 'admin', account_kind = 'staff'
WHERE role IS NOT NULL AND role = 'admin' AND app_role = 'end_user';

ALTER TABLE public.knowledge_repository_documents
  ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS visibility_rules jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS consent_agreed_at timestamptz,
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES public.user_profiles (id),
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;

ALTER TABLE public.knowledge_repository_documents
  DROP CONSTRAINT IF EXISTS knowledge_repository_documents_approval_status_check;
ALTER TABLE public.knowledge_repository_documents
  ADD CONSTRAINT knowledge_repository_documents_approval_status_check
  CHECK (approval_status IN ('pending', 'approved', 'rejected'));

ALTER TABLE public.workshop_documents
  ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS visibility_rules jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS consent_agreed_at timestamptz,
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES public.user_profiles (id),
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;

ALTER TABLE public.workshop_documents
  DROP CONSTRAINT IF EXISTS workshop_documents_approval_status_check;
ALTER TABLE public.workshop_documents
  ADD CONSTRAINT workshop_documents_approval_status_check
  CHECK (approval_status IN ('pending', 'approved', 'rejected'));

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid REFERENCES public.user_profiles (id) ON DELETE SET NULL,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON public.audit_logs (actor_id);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT ON public.audit_logs TO authenticated;
GRANT SELECT ON public.audit_logs TO service_role;

CREATE OR REPLACE FUNCTION public.dashboard_is_staff()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles p
    WHERE p.id = auth.uid()
      AND p.account_kind = 'staff'
      AND p.app_role IN ('moderator', 'admin', 'super_admin')
  );
$$;

CREATE OR REPLACE FUNCTION public.dashboard_is_super_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles p
    WHERE p.id = auth.uid()
      AND p.account_kind = 'staff'
      AND p.app_role = 'super_admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.dashboard_is_admin_or_super()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_profiles p
    WHERE p.id = auth.uid()
      AND p.account_kind = 'staff'
      AND p.app_role IN ('admin', 'super_admin')
  );
$$;

DROP POLICY IF EXISTS audit_logs_insert_staff ON public.audit_logs;
CREATE POLICY audit_logs_insert_staff
  ON public.audit_logs FOR INSERT TO authenticated
  WITH CHECK (actor_id = auth.uid() AND public.dashboard_is_staff());

DROP POLICY IF EXISTS audit_logs_select_elevated ON public.audit_logs;
CREATE POLICY audit_logs_select_elevated
  ON public.audit_logs FOR SELECT TO authenticated
  USING (public.dashboard_is_super_admin());

DROP POLICY IF EXISTS user_profiles_staff_select_all ON public.user_profiles;
CREATE POLICY user_profiles_staff_select_all
  ON public.user_profiles FOR SELECT TO authenticated
  USING (public.dashboard_is_staff());

DROP POLICY IF EXISTS user_profiles_admin_update_farmers ON public.user_profiles;
CREATE POLICY user_profiles_admin_update_farmers
  ON public.user_profiles FOR UPDATE TO authenticated
  USING (
    public.dashboard_is_admin_or_super()
    AND account_kind = 'farmer'
  )
  WITH CHECK (account_kind = 'farmer');

DROP POLICY IF EXISTS user_profiles_super_admin_update_all ON public.user_profiles;
CREATE POLICY user_profiles_super_admin_update_all
  ON public.user_profiles FOR UPDATE TO authenticated
  USING (public.dashboard_is_super_admin())
  WITH CHECK (true);

DROP POLICY IF EXISTS knowledge_repo_staff_update ON public.knowledge_repository_documents;
CREATE POLICY knowledge_repo_staff_update
  ON public.knowledge_repository_documents FOR UPDATE TO authenticated
  USING (public.dashboard_is_staff())
  WITH CHECK (true);

DROP POLICY IF EXISTS workshop_docs_staff_update ON public.workshop_documents;
CREATE POLICY workshop_docs_staff_update
  ON public.workshop_documents FOR UPDATE TO authenticated
  USING (public.dashboard_is_staff())
  WITH CHECK (true);

DROP POLICY IF EXISTS knowledge_repo_staff_select_all ON public.knowledge_repository_documents;
CREATE POLICY knowledge_repo_staff_select_all
  ON public.knowledge_repository_documents FOR SELECT TO authenticated
  USING (public.dashboard_is_staff());

DROP POLICY IF EXISTS workshop_docs_staff_select_all ON public.workshop_documents;
CREATE POLICY workshop_docs_staff_select_all
  ON public.workshop_documents FOR SELECT TO authenticated
  USING (public.dashboard_is_staff());
