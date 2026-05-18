
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS acreage numeric,
  ADD COLUMN IF NOT EXISTS crop_types text,
  ADD COLUMN IF NOT EXISTS practice_stage text;

ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS virtual_meeting_url text,
  ADD COLUMN IF NOT EXISTS registration_open boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS latitude double precision,
  ADD COLUMN IF NOT EXISTS longitude double precision;

ALTER TABLE public.event_registrations
  ADD COLUMN IF NOT EXISTS registration_slot_status text NOT NULL DEFAULT 'confirmed',
  ADD COLUMN IF NOT EXISTS waitlist_position integer,
  ADD COLUMN IF NOT EXISTS attendance_status text NOT NULL DEFAULT 'registered';

ALTER TABLE public.event_registrations
  DROP CONSTRAINT IF EXISTS event_registrations_slot_status_check;
ALTER TABLE public.event_registrations
  ADD CONSTRAINT event_registrations_slot_status_check
  CHECK (registration_slot_status IN ('confirmed', 'waitlist', 'cancelled'));

ALTER TABLE public.event_registrations
  DROP CONSTRAINT IF EXISTS event_registrations_attendance_check;
ALTER TABLE public.event_registrations
  ADD CONSTRAINT event_registrations_attendance_check
  CHECK (attendance_status IN ('registered', 'attended', 'no_show', 'cancelled'));

CREATE TABLE IF NOT EXISTS public.app_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES public.user_profiles (id)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_settings TO authenticated;
GRANT ALL ON public.app_settings TO service_role;

CREATE TABLE IF NOT EXISTS public.broadcast_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  channel text NOT NULL DEFAULT 'email',
  segment jsonb NOT NULL DEFAULT '{}'::jsonb,
  scheduled_for timestamptz,
  status text NOT NULL DEFAULT 'draft',
  created_by uuid REFERENCES public.user_profiles (id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.broadcast_campaigns
  DROP CONSTRAINT IF EXISTS broadcast_campaigns_channel_check;
ALTER TABLE public.broadcast_campaigns
  ADD CONSTRAINT broadcast_campaigns_channel_check
  CHECK (channel IN ('push', 'sms', 'email', 'in_app'));

ALTER TABLE public.broadcast_campaigns
  DROP CONSTRAINT IF EXISTS broadcast_campaigns_status_check;
ALTER TABLE public.broadcast_campaigns
  ADD CONSTRAINT broadcast_campaigns_status_check
  CHECK (status IN ('draft', 'scheduled', 'sending', 'sent', 'failed', 'cancelled'));

CREATE INDEX IF NOT EXISTS idx_broadcast_campaigns_status ON public.broadcast_campaigns (status);

CREATE TABLE IF NOT EXISTS public.broadcast_delivery_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES public.broadcast_campaigns (id) ON DELETE CASCADE,
  recipient_id uuid REFERENCES public.user_profiles (id) ON DELETE SET NULL,
  status text NOT NULL,
  detail jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_broadcast_delivery_campaign ON public.broadcast_delivery_events (campaign_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.broadcast_campaigns TO authenticated;
GRANT SELECT, INSERT ON public.broadcast_delivery_events TO authenticated;

CREATE OR REPLACE FUNCTION public.visibility_rules_allow_document(rules jsonb, viewer_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
<<vis>>
DECLARE
  tiers jsonb;
  uids jsonb;
  viewer_tier text;
BEGIN
  IF rules IS NULL OR rules = '{}'::jsonb THEN
    RETURN true;
  END IF;

  uids := rules -> 'user_ids';
  IF uids IS NOT NULL AND jsonb_typeof(uids) = 'array' THEN
    IF EXISTS (
      SELECT 1
      FROM jsonb_array_elements_text(uids) AS uid_row(uid_txt)
      WHERE uid_row.uid_txt = viewer_id::text
    ) THEN
      RETURN true;
    END IF;
  END IF;

  tiers := rules -> 'tiers';
  IF tiers IS NULL OR jsonb_typeof(tiers) <> 'array' OR jsonb_array_length(tiers) = 0 THEN
    RETURN true;
  END IF;

  SELECT p.access_tier INTO viewer_tier
  FROM public.user_profiles AS p
  WHERE p.id = viewer_id;

  IF vis.viewer_tier IS NULL OR btrim(vis.viewer_tier) = '' THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM jsonb_array_elements_text(tiers) AS tier_row(tier_val)
    WHERE tier_val IS NOT NULL
      AND btrim(tier_val) <> ''
      AND tier_val = vis.viewer_tier
  );
END;
$$;
