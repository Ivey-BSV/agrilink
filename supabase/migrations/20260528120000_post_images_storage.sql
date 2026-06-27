INSERT INTO storage.buckets (id, name, public)
VALUES
  ('post-images', 'post-images', true),
  ('post-videos', 'post-videos', true),
  ('marketplace-images', 'marketplace-images', true),
  ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS post_images_storage_select ON storage.objects;
CREATE POLICY post_images_storage_select
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'post-images');

DROP POLICY IF EXISTS post_images_storage_insert ON storage.objects;
CREATE POLICY post_images_storage_insert
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'post-images'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS post_images_storage_delete_own ON storage.objects;
CREATE POLICY post_images_storage_delete_own
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'post-images'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS post_videos_storage_select ON storage.objects;
CREATE POLICY post_videos_storage_select
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'post-videos');

DROP POLICY IF EXISTS post_videos_storage_insert ON storage.objects;
CREATE POLICY post_videos_storage_insert
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'post-videos'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS post_videos_storage_delete_own ON storage.objects;
CREATE POLICY post_videos_storage_delete_own
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'post-videos'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS marketplace_images_storage_select ON storage.objects;
CREATE POLICY marketplace_images_storage_select
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'marketplace-images');

DROP POLICY IF EXISTS marketplace_images_storage_insert ON storage.objects;
CREATE POLICY marketplace_images_storage_insert
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'marketplace-images'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS marketplace_images_storage_delete_own ON storage.objects;
CREATE POLICY marketplace_images_storage_delete_own
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'marketplace-images'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS avatars_storage_select ON storage.objects;
CREATE POLICY avatars_storage_select
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS avatars_storage_insert ON storage.objects;
CREATE POLICY avatars_storage_insert
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND split_part(name, '/', 1) = auth.uid()::text
  );

DROP POLICY IF EXISTS avatars_storage_delete_own ON storage.objects;
CREATE POLICY avatars_storage_delete_own
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND split_part(name, '/', 1) = auth.uid()::text
  );
