CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.dispatch_push_notification_webhook()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  push_secret text;
  push_url text := 'https://gugzmorionjucepcouyr.supabase.co/functions/v1/push_notification';
  request_id bigint;
BEGIN
  SELECT decrypted_secret
  INTO push_secret
  FROM vault.decrypted_secrets
  WHERE name = 'cap_push_webhook_secret'
  LIMIT 1;

  IF push_secret IS NULL OR length(trim(push_secret)) = 0 THEN
    RETURN NEW;
  END IF;

  SELECT net.http_post(
    url := push_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cap-push-secret', push_secret
    ),
    body := jsonb_build_object(
      'type', TG_OP,
      'table', TG_TABLE_NAME,
      'schema', TG_TABLE_SCHEMA,
      'record', row_to_json(NEW)
    )
  )
  INTO request_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS push_notification_webhook ON public.user_notifications;

CREATE TRIGGER push_notification_webhook
  AFTER INSERT ON public.user_notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.dispatch_push_notification_webhook();
