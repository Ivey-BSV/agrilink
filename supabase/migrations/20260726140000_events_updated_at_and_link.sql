-- Events: support save timestamps + optional link on listings (Jeff Pastorius feedback)

ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS link_url text;

COMMENT ON COLUMN public.events.link_url IS
  'Optional public URL for registration, more info, or related materials.';

COMMENT ON COLUMN public.events.virtual_meeting_url IS
  'Optional video-call URL for virtual attendance.';

UPDATE public.events
SET updated_at = COALESCE(created_at, now())
WHERE updated_at IS NULL;
