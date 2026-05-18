
CREATE TABLE IF NOT EXISTS public.user_notification_settings (
  user_id uuid PRIMARY KEY REFERENCES public.user_profiles (id) ON DELETE CASCADE,
  notify_new_posts_feed boolean NOT NULL DEFAULT true,
  notify_new_polls boolean NOT NULL DEFAULT true,
  notify_post_likes boolean NOT NULL DEFAULT true,
  notify_post_comments boolean NOT NULL DEFAULT true,
  notify_poll_closed boolean NOT NULL DEFAULT true,
  notify_new_followers boolean NOT NULL DEFAULT true,
  notify_chat_messages boolean NOT NULL DEFAULT true,
  notify_project_activity boolean NOT NULL DEFAULT true,
  push_enabled boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.user_notification_settings IS
  'Toggles for notification categories; push_enabled reserved for FCM wiring.';

INSERT INTO public.user_notification_settings (user_id)
SELECT id FROM public.user_profiles
ON CONFLICT (user_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.user_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.user_profiles (id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  body text,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS user_notifications_user_created_idx
  ON public.user_notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS user_notifications_unread_idx
  ON public.user_notifications (user_id)
  WHERE read_at IS NULL;

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS fcm_token text;

COMMENT ON COLUMN public.user_profiles.fcm_token IS
  'FCM device token when user opts into push; set from mobile after Firebase setup.';

CREATE OR REPLACE FUNCTION public.touch_notification_settings_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notification_settings_updated ON public.user_notification_settings;
CREATE TRIGGER trg_notification_settings_updated
  BEFORE UPDATE ON public.user_notification_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_notification_settings_updated_at();

CREATE OR REPLACE FUNCTION public.notify_on_new_post()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  SELECT u.id,
    'post_new',
    'New community post',
    COALESCE(left(NEW.title, 140), 'Someone shared a post'),
    jsonb_build_object('post_id', NEW.id::text, 'author_id', NEW.user_id::text)
  FROM public.user_profiles u
  LEFT JOIN public.user_notification_settings s ON s.user_id = u.id
  WHERE u.id IS DISTINCT FROM NEW.user_id
    AND COALESCE(s.notify_new_posts_feed, true) = true;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_posts_notify_new ON public.posts;
CREATE TRIGGER trg_posts_notify_new
  AFTER INSERT ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_new_post();

CREATE OR REPLACE FUNCTION public.notify_on_new_poll()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  SELECT u.id,
    'poll_new',
    'New poll',
    COALESCE(left(NEW.title, 140), 'Someone started a poll'),
    jsonb_build_object('poll_id', NEW.id::text, 'creator_id', NEW.created_by::text)
  FROM public.user_profiles u
  LEFT JOIN public.user_notification_settings s ON s.user_id = u.id
  WHERE u.id IS DISTINCT FROM NEW.created_by
    AND COALESCE(s.notify_new_polls, true) = true;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_polls_notify_new ON public.polls;
CREATE TRIGGER trg_polls_notify_new
  AFTER INSERT ON public.polls
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_new_poll();

CREATE OR REPLACE FUNCTION public.notify_on_poll_closed()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status = 'closed' AND COALESCE(OLD.status, '') IS DISTINCT FROM 'closed' THEN
    INSERT INTO public.user_notifications (user_id, type, title, body, data)
    SELECT DISTINCT pv.user_id,
      'poll_closed',
      'Poll closed',
      COALESCE(left(NEW.title, 120), 'A poll you voted in has closed'),
      jsonb_build_object('poll_id', NEW.id::text)
    FROM public.poll_votes pv
    LEFT JOIN public.user_notification_settings s ON s.user_id = pv.user_id
    WHERE pv.poll_id = NEW.id
      AND COALESCE(s.notify_poll_closed, true) = true;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_polls_notify_closed ON public.polls;
CREATE TRIGGER trg_polls_notify_closed
  AFTER UPDATE ON public.polls
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_poll_closed();

CREATE TABLE IF NOT EXISTS public.post_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.posts (id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.user_profiles (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON public.post_likes (post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON public.post_likes (user_id);

ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "post_likes_select_authenticated" ON public.post_likes;
CREATE POLICY "post_likes_select_authenticated"
  ON public.post_likes
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "post_likes_insert_own" ON public.post_likes;
CREATE POLICY "post_likes_insert_own"
  ON public.post_likes
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "post_likes_delete_own" ON public.post_likes;
CREATE POLICY "post_likes_delete_own"
  ON public.post_likes
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.notify_on_post_like()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  owner_id uuid;
BEGIN
  SELECT p.user_id INTO owner_id FROM public.posts p WHERE p.id = NEW.post_id;
  IF owner_id IS NULL OR owner_id = NEW.user_id THEN
    RETURN NEW;
  END IF;
  IF NOT COALESCE(
    (SELECT notify_post_likes FROM public.user_notification_settings WHERE user_id = owner_id),
    true
  ) THEN
    RETURN NEW;
  END IF;
  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  VALUES (
    owner_id,
    'post_like',
    'Someone liked your post',
    'Your post received a like',
    jsonb_build_object('post_id', NEW.post_id::text, 'liker_id', NEW.user_id::text)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_post_likes_notify ON public.post_likes;
CREATE TRIGGER trg_post_likes_notify
  AFTER INSERT ON public.post_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_post_like();

CREATE OR REPLACE FUNCTION public.notify_on_post_comment()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  owner_id uuid;
BEGIN
  SELECT p.user_id INTO owner_id FROM public.posts p WHERE p.id = NEW.post_id;
  IF owner_id IS NULL OR owner_id = NEW.user_id THEN
    RETURN NEW;
  END IF;
  IF NOT COALESCE(
    (SELECT notify_post_comments FROM public.user_notification_settings WHERE user_id = owner_id),
    true
  ) THEN
    RETURN NEW;
  END IF;
  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  VALUES (
    owner_id,
    'post_comment',
    'New comment on your post',
    left(NEW.content, 160),
    jsonb_build_object('post_id', NEW.post_id::text, 'comment_id', NEW.id::text, 'commenter_id', NEW.user_id::text)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_comments_notify ON public.comments;
CREATE TRIGGER trg_comments_notify
  AFTER INSERT ON public.comments
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_post_comment();

CREATE OR REPLACE FUNCTION public.notify_on_new_follower()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT COALESCE(
    (SELECT notify_new_followers FROM public.user_notification_settings WHERE user_id = NEW.following_id),
    true
  ) THEN
    RETURN NEW;
  END IF;
  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  VALUES (
    NEW.following_id,
    'follow_new',
    'New follower',
    'Someone started following you',
    jsonb_build_object('follower_id', NEW.follower_id::text)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_follows_notify ON public.follows;
CREATE TRIGGER trg_follows_notify
  AFTER INSERT ON public.follows
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_new_follower();

CREATE OR REPLACE FUNCTION public.notify_on_chat_message()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  u1 uuid;
  u2 uuid;
  recipient uuid;
BEGIN
  SELECT c.user1_id, c.user2_id INTO u1, u2
  FROM public.chats c WHERE c.id = NEW.chat_id;
  IF u1 IS NULL THEN RETURN NEW; END IF;
  recipient := CASE WHEN NEW.sender_id = u1 THEN u2 ELSE u1 END;
  IF recipient IS NULL OR recipient = NEW.sender_id THEN RETURN NEW; END IF;
  IF NOT COALESCE(
    (SELECT notify_chat_messages FROM public.user_notification_settings WHERE user_id = recipient),
    true
  ) THEN
    RETURN NEW;
  END IF;
  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  VALUES (
    recipient,
    'chat_message',
    'New message',
    left(NEW.content, 160),
    jsonb_build_object('chat_id', NEW.chat_id::text, 'sender_id', NEW.sender_id::text, 'message_id', NEW.id::text)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_messages_notify ON public.messages;
CREATE TRIGGER trg_messages_notify
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_chat_message();

CREATE OR REPLACE FUNCTION public.notify_on_project_join()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r record;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.goals g
    WHERE g.id = NEW.goal_id AND lower(coalesce(g.goal_type, '')) = 'community'
  ) THEN
    RETURN NEW;
  END IF;

  FOR r IN
    SELECT DISTINCT x.uid FROM (
      SELECT cgp.user_id AS uid
      FROM public.community_goal_participants cgp
      WHERE cgp.goal_id = NEW.goal_id
        AND cgp.user_id IS DISTINCT FROM NEW.user_id
      UNION
      SELECT g.user_id AS uid
      FROM public.goals g
      WHERE g.id = NEW.goal_id
        AND g.user_id IS DISTINCT FROM NEW.user_id
    ) x
  LOOP
    IF COALESCE(
      (SELECT notify_project_activity FROM public.user_notification_settings WHERE user_id = r.uid),
      true
    ) THEN
      INSERT INTO public.user_notifications (user_id, type, title, body, data)
      VALUES (
        r.uid,
        'project_join',
        'Someone joined your project',
        'A new member joined a community project you''re in',
        jsonb_build_object('goal_id', NEW.goal_id::text, 'new_member_id', NEW.user_id::text)
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_community_goal_join_notify ON public.community_goal_participants;
CREATE TRIGGER trg_community_goal_join_notify
  AFTER INSERT ON public.community_goal_participants
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_on_project_join();

ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notification_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_notifications_select_own ON public.user_notifications;
CREATE POLICY user_notifications_select_own
  ON public.user_notifications FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS user_notifications_update_own ON public.user_notifications;
CREATE POLICY user_notifications_update_own
  ON public.user_notifications FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS user_notifications_delete_own ON public.user_notifications;
CREATE POLICY user_notifications_delete_own
  ON public.user_notifications FOR DELETE TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS user_notification_settings_select_own ON public.user_notification_settings;
CREATE POLICY user_notification_settings_select_own
  ON public.user_notification_settings FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS user_notification_settings_upsert_own ON public.user_notification_settings;
CREATE POLICY user_notification_settings_upsert_own
  ON public.user_notification_settings FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS user_notification_settings_update_own ON public.user_notification_settings;
CREATE POLICY user_notification_settings_update_own
  ON public.user_notification_settings FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
