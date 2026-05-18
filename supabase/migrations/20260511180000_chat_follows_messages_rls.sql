
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own chats" ON public.chats;
DROP POLICY IF EXISTS "chat_select_participant_v2" ON public.chats;
CREATE POLICY "chat_select_participant_v2"
  ON public.chats FOR SELECT
  TO authenticated
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

DROP POLICY IF EXISTS "Users can create chats" ON public.chats;
DROP POLICY IF EXISTS "chat_insert_as_user1_v2" ON public.chats;
CREATE POLICY "chat_insert_as_user1_v2"
  ON public.chats FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user1_id);

DROP POLICY IF EXISTS "Users can update their own chats" ON public.chats;
DROP POLICY IF EXISTS "chat_update_participant_v2" ON public.chats;
CREATE POLICY "chat_update_participant_v2"
  ON public.chats FOR UPDATE
  TO authenticated
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view messages in their chats" ON public.messages;
DROP POLICY IF EXISTS "messages_select_in_my_chats_v2" ON public.messages;
CREATE POLICY "messages_select_in_my_chats_v2"
  ON public.messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chats c
      WHERE c.id = messages.chat_id
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can send messages in their chats" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_in_my_chats_v2" ON public.messages;
CREATE POLICY "messages_insert_in_my_chats_v2"
  ON public.messages FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM public.chats c
      WHERE c.id = messages.chat_id
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can update messages in their chats" ON public.messages;
DROP POLICY IF EXISTS "messages_update_in_my_chats_v2" ON public.messages;
CREATE POLICY "messages_update_in_my_chats_v2"
  ON public.messages FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chats c
      WHERE c.id = messages.chat_id
        AND (c.user1_id = auth.uid() OR c.user2_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "follows_select_visible_v2" ON public.follows;
CREATE POLICY "follows_select_visible_v2"
  ON public.follows FOR SELECT
  TO authenticated
  USING (follower_id = auth.uid() OR following_id = auth.uid());
