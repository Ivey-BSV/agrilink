DO $drop_like_policy$
BEGIN
  IF to_regclass('public.post_likes') IS NOT NULL THEN
    EXECUTE 'DROP POLICY IF EXISTS post_likes_super_admin_delete ON public.post_likes';
  END IF;
END
$drop_like_policy$;
