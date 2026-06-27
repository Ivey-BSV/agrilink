-- In-app (and push webhook) notifications for repository & workshop folders/files/links.

ALTER TABLE public.user_notification_settings
  ADD COLUMN IF NOT EXISTS notify_repository_activity boolean NOT NULL DEFAULT true;

ALTER TABLE public.user_notification_settings
  ADD COLUMN IF NOT EXISTS notify_workshop_activity boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.user_notification_settings.notify_repository_activity IS
  'Notify when someone adds files or links to a repository folder.';
COMMENT ON COLUMN public.user_notification_settings.notify_workshop_activity IS
  'Notify when someone adds files or links to a workshop folder.';

CREATE OR REPLACE FUNCTION public.notify_on_resource_document()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  folder_scope text;
  folder_name text;
  actor_name text;
  notif_type text;
  notif_title text;
  action_verb text;
  is_link boolean;
BEGIN
  IF COALESCE(NEW.approval_status, 'approved') <> 'approved' THEN
    RETURN NEW;
  END IF;

  IF NEW.folder_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT rf.scope, rf.name INTO folder_scope, folder_name
  FROM public.resource_folders rf
  WHERE rf.id = NEW.folder_id;

  IF folder_scope IS NULL THEN
    RETURN NEW;
  END IF;

  is_link := lower(COALESCE(NEW.mime_type, '')) IN ('text/uri-list', 'video/youtube');
  action_verb := CASE WHEN is_link THEN 'added a link' ELSE 'uploaded a file' END;

  IF folder_scope = 'repository' THEN
    notif_type := 'repository_item_new';
    notif_title := 'New repository item';
  ELSE
    notif_type := 'workshop_item_new';
    notif_title := 'New workshop item';
  END IF;

  SELECT COALESCE(
    NULLIF(trim(full_name), ''),
    NULLIF(trim(username), ''),
    'Someone'
  )
  INTO actor_name
  FROM public.user_profiles
  WHERE id = NEW.user_id;

  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  SELECT u.id,
    notif_type,
    notif_title,
    left(
      actor_name || ' ' || action_verb || ': “'
        || COALESCE(NEW.title, 'Untitled') || '” in '
        || COALESCE(folder_name, 'a folder'),
      200
    ),
    jsonb_build_object(
      'scope', folder_scope,
      'folder_id', NEW.folder_id::text,
      'document_id', NEW.id::text,
      'actor_id', NEW.user_id::text,
      'is_link', is_link
    )
  FROM public.user_profiles u
  LEFT JOIN public.user_notification_settings s ON s.user_id = u.id
  WHERE u.id IS DISTINCT FROM NEW.user_id
    AND (
      (folder_scope = 'repository' AND COALESCE(s.notify_repository_activity, true) = true)
      OR (folder_scope = 'workshop' AND COALESCE(s.notify_workshop_activity, true) = true)
    );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_knowledge_repo_doc_notify ON public.knowledge_repository_documents;
CREATE TRIGGER trg_knowledge_repo_doc_notify
  AFTER INSERT ON public.knowledge_repository_documents
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_resource_document();

DROP TRIGGER IF EXISTS trg_workshop_doc_notify ON public.workshop_documents;
CREATE TRIGGER trg_workshop_doc_notify
  AFTER INSERT ON public.workshop_documents
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_resource_document();

CREATE OR REPLACE FUNCTION public.notify_on_resource_folder()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  actor_name text;
  notif_type text;
  notif_title text;
BEGIN
  IF NEW.scope = 'repository' THEN
    notif_type := 'repository_folder_new';
    notif_title := 'New repository folder';
  ELSE
    notif_type := 'workshop_folder_new';
    notif_title := 'New workshop folder';
  END IF;

  SELECT COALESCE(
    NULLIF(trim(full_name), ''),
    NULLIF(trim(username), ''),
    'Someone'
  )
  INTO actor_name
  FROM public.user_profiles
  WHERE id = NEW.created_by;

  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  SELECT u.id,
    notif_type,
    notif_title,
    left(actor_name || ' created folder “' || NEW.name || '”', 200),
    jsonb_build_object(
      'scope', NEW.scope,
      'folder_id', NEW.id::text,
      'actor_id', NEW.created_by::text
    )
  FROM public.user_profiles u
  LEFT JOIN public.user_notification_settings s ON s.user_id = u.id
  WHERE u.id IS DISTINCT FROM NEW.created_by
    AND (
      (NEW.scope = 'repository' AND COALESCE(s.notify_repository_activity, true) = true)
      OR (NEW.scope = 'workshop' AND COALESCE(s.notify_workshop_activity, true) = true)
    );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_resource_folders_notify ON public.resource_folders;
CREATE TRIGGER trg_resource_folders_notify
  AFTER INSERT ON public.resource_folders
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_resource_folder();
