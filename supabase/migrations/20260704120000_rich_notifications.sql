-- Richer notifications: include the acting user's name and useful context
-- in titles/bodies so push notifications read like real messages
-- (e.g. "Isam Karimi" / "See you at the workshop!" instead of "New message").

CREATE OR REPLACE FUNCTION public.notification_display_name(p_user_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(NULLIF(trim(full_name), ''), NULLIF(trim(username), ''), 'Someone')
  FROM public.user_profiles
  WHERE id = p_user_id;
$$;

-- Chat: title is the sender's name, body is the message preview.
CREATE OR REPLACE FUNCTION public.notify_on_chat_message()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  u1 uuid;
  u2 uuid;
  recipient uuid;
  sender_name text;
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

  sender_name := COALESCE(public.notification_display_name(NEW.sender_id), 'Someone');

  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  VALUES (
    recipient,
    'chat_message',
    sender_name,
    COALESCE(NULLIF(left(trim(NEW.content), 160), ''), 'Sent you a message'),
    jsonb_build_object(
      'chat_id', NEW.chat_id::text,
      'sender_id', NEW.sender_id::text,
      'message_id', NEW.id::text
    )
  );
  RETURN NEW;
END;
$$;

-- New community post: author name + post preview.
CREATE OR REPLACE FUNCTION public.notify_on_new_post()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  author_name text;
BEGIN
  author_name := COALESCE(public.notification_display_name(NEW.user_id), 'Someone');

  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  SELECT u.id,
    'post_new',
    author_name || ' shared a new post',
    COALESCE(
      NULLIF(left(trim(NEW.title), 140), ''),
      NULLIF(left(trim(NEW.content), 140), ''),
      'Tap to view the post'
    ),
    jsonb_build_object('post_id', NEW.id::text, 'author_id', NEW.user_id::text)
  FROM public.user_profiles u
  LEFT JOIN public.user_notification_settings s ON s.user_id = u.id
  WHERE u.id IS DISTINCT FROM NEW.user_id
    AND COALESCE(s.notify_new_posts_feed, true) = true;
  RETURN NEW;
END;
$$;

-- New poll: creator name + poll title.
CREATE OR REPLACE FUNCTION public.notify_on_new_poll()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  creator_name text;
BEGIN
  creator_name := COALESCE(public.notification_display_name(NEW.created_by), 'Someone');

  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  SELECT u.id,
    'poll_new',
    creator_name || ' started a poll',
    COALESCE(NULLIF(left(trim(NEW.title), 140), ''), 'Tap to vote'),
    jsonb_build_object('poll_id', NEW.id::text, 'creator_id', NEW.created_by::text)
  FROM public.user_profiles u
  LEFT JOIN public.user_notification_settings s ON s.user_id = u.id
  WHERE u.id IS DISTINCT FROM NEW.created_by
    AND COALESCE(s.notify_new_polls, true) = true;
  RETURN NEW;
END;
$$;

-- Poll closed: mention the poll by name.
CREATE OR REPLACE FUNCTION public.notify_on_poll_closed()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status = 'closed' AND COALESCE(OLD.status, '') IS DISTINCT FROM 'closed' THEN
    INSERT INTO public.user_notifications (user_id, type, title, body, data)
    SELECT DISTINCT pv.user_id,
      'poll_closed',
      'Poll results are in',
      left('Voting has ended for “' || COALESCE(NULLIF(trim(NEW.title), ''), 'a poll you voted in') || '” — tap to see the results', 200),
      jsonb_build_object('poll_id', NEW.id::text)
    FROM public.poll_votes pv
    LEFT JOIN public.user_notification_settings s ON s.user_id = pv.user_id
    WHERE pv.poll_id = NEW.id
      AND COALESCE(s.notify_poll_closed, true) = true;
  END IF;
  RETURN NEW;
END;
$$;

-- Post like: who liked it, and which post.
CREATE OR REPLACE FUNCTION public.notify_on_post_like()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  owner_id uuid;
  post_preview text;
  liker_name text;
BEGIN
  SELECT p.user_id,
    COALESCE(NULLIF(left(trim(p.title), 120), ''), NULLIF(left(trim(p.content), 120), ''))
  INTO owner_id, post_preview
  FROM public.posts p WHERE p.id = NEW.post_id;

  IF owner_id IS NULL OR owner_id = NEW.user_id THEN
    RETURN NEW;
  END IF;
  IF NOT COALESCE(
    (SELECT notify_post_likes FROM public.user_notification_settings WHERE user_id = owner_id),
    true
  ) THEN
    RETURN NEW;
  END IF;

  liker_name := COALESCE(public.notification_display_name(NEW.user_id), 'Someone');

  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  VALUES (
    owner_id,
    'post_like',
    liker_name || ' liked your post',
    COALESCE('“' || post_preview || '”', 'Your post received a like'),
    jsonb_build_object('post_id', NEW.post_id::text, 'liker_id', NEW.user_id::text)
  );
  RETURN NEW;
END;
$$;

-- Post comment: who commented + what they said.
CREATE OR REPLACE FUNCTION public.notify_on_post_comment()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  owner_id uuid;
  commenter_name text;
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

  commenter_name := COALESCE(public.notification_display_name(NEW.user_id), 'Someone');

  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  VALUES (
    owner_id,
    'post_comment',
    commenter_name || ' commented on your post',
    COALESCE(NULLIF(left(trim(NEW.content), 160), ''), 'Tap to view the comment'),
    jsonb_build_object('post_id', NEW.post_id::text, 'comment_id', NEW.id::text, 'commenter_id', NEW.user_id::text)
  );
  RETURN NEW;
END;
$$;

-- New follower: who followed you.
CREATE OR REPLACE FUNCTION public.notify_on_new_follower()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  follower_name text;
  follower_username text;
BEGIN
  IF NOT COALESCE(
    (SELECT notify_new_followers FROM public.user_notification_settings WHERE user_id = NEW.following_id),
    true
  ) THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(NULLIF(trim(full_name), ''), NULLIF(trim(username), ''), 'Someone'),
    NULLIF(trim(username), '')
  INTO follower_name, follower_username
  FROM public.user_profiles
  WHERE id = NEW.follower_id;

  INSERT INTO public.user_notifications (user_id, type, title, body, data)
  VALUES (
    NEW.following_id,
    'follow_new',
    COALESCE(follower_name, 'Someone') || ' started following you',
    CASE WHEN follower_username IS NOT NULL
      THEN '@' || follower_username || ' — tap to view their profile'
      ELSE 'Tap to view their profile'
    END,
    jsonb_build_object('follower_id', NEW.follower_id::text)
  );
  RETURN NEW;
END;
$$;

-- Project join: who joined which project.
CREATE OR REPLACE FUNCTION public.notify_on_project_join()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r record;
  joiner_name text;
  project_title text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.goals g
    WHERE g.id = NEW.goal_id AND lower(coalesce(g.goal_type, '')) = 'community'
  ) THEN
    RETURN NEW;
  END IF;

  joiner_name := COALESCE(public.notification_display_name(NEW.user_id), 'Someone');
  SELECT NULLIF(left(trim(g.title), 120), '') INTO project_title
  FROM public.goals g WHERE g.id = NEW.goal_id;

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
        joiner_name || ' joined your project',
        COALESCE('They joined “' || project_title || '”', 'A new member joined a community project you''re in'),
        jsonb_build_object('goal_id', NEW.goal_id::text, 'new_member_id', NEW.user_id::text)
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;
