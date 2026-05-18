
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own chats" ON public.chats;
DROP POLICY IF EXISTS "chat_select_participant_v2" ON public.chats;
DROP POLICY IF EXISTS "chat_select_participant_v3" ON public.chats;
CREATE POLICY "chat_select_participant_v3"
  ON public.chats FOR SELECT
  USING (auth.uid() IS NOT NULL AND (auth.uid() = user1_id OR auth.uid() = user2_id));

DROP POLICY IF EXISTS "Users can create chats" ON public.chats;
DROP POLICY IF EXISTS "chat_insert_as_user1_v2" ON public.chats;
DROP POLICY IF EXISTS "chat_insert_as_user1_v3" ON public.chats;
CREATE POLICY "chat_insert_as_user1_v3"
  ON public.chats FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL AND auth.uid() = user1_id);

DROP POLICY IF EXISTS "Users can update their own chats" ON public.chats;
DROP POLICY IF EXISTS "chat_update_participant_v2" ON public.chats;
DROP POLICY IF EXISTS "chat_update_participant_v3" ON public.chats;
CREATE POLICY "chat_update_participant_v3"
  ON public.chats FOR UPDATE
  USING (auth.uid() IS NOT NULL AND (auth.uid() = user1_id OR auth.uid() = user2_id));

DROP POLICY IF EXISTS "Users can view messages in their chats" ON public.messages;
DROP POLICY IF EXISTS "messages_select_in_my_chats_v2" ON public.messages;
DROP POLICY IF EXISTS "messages_select_in_my_chats_v3" ON public.messages;
CREATE POLICY "messages_select_in_my_chats_v3"
  ON public.messages FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.chats c
      WHERE c.id = messages.chat_id
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can send messages in their chats" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_in_my_chats_v2" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_in_my_chats_v3" ON public.messages;
CREATE POLICY "messages_insert_in_my_chats_v3"
  ON public.messages FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM public.chats c
      WHERE c.id = messages.chat_id
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can update messages in their chats" ON public.messages;
DROP POLICY IF EXISTS "messages_update_in_my_chats_v2" ON public.messages;
DROP POLICY IF EXISTS "messages_update_in_my_chats_v3" ON public.messages;
CREATE POLICY "messages_update_in_my_chats_v3"
  ON public.messages FOR UPDATE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.chats c
      WHERE c.id = messages.chat_id
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "follows_select_visible_v2" ON public.follows;
DROP POLICY IF EXISTS "follows_select_visible_v3" ON public.follows;
CREATE POLICY "follows_select_visible_v3"
  ON public.follows FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND (follower_id = auth.uid() OR following_id = auth.uid())
  );
