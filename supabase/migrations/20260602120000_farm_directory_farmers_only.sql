-- Farm directory shows only profiles with account_kind = 'farmer'.
-- Staff / non-farmer accounts use account_kind = 'staff' (app_role unchanged).
-- New signups default to farmer; assign staff manually for team and test accounts.

UPDATE public.user_profiles
SET account_kind = 'staff'
WHERE lower(username) IN (
  'anselzeng',
  'isam',
  'isam1',
  'usharma',
  'usharma101',
  'appletest',
  'gualandris',
  'isam_2',
  'arjalies',
  'di_iorio',
  'jeff'
);

COMMENT ON COLUMN public.user_profiles.account_kind IS
  'farmer = listed in farm directory; staff = team/test accounts (use app_role for dashboard access)';
