# admin_operations

Privileged staff actions (uses `SUPABASE_SERVICE_ROLE_KEY`). Deploy:

```bash
supabase functions deploy admin_operations
```

The dashboard invokes this with the signed-in user’s JWT (`supabase.functions.invoke`).

## Actions (POST JSON)

| `action` | Who | Body |
|----------|-----|------|
| `create_staff` | Super | `email`, `password`, `app_role`, optional `full_name` |
| `invite_farmer` | Admin+ | `email`, `password`, optional `full_name`, `registration_status`, `access_tier` |
| `revoke_staff_access` | Super | `target_user_id` — sets farmer / end_user |
| `update_user_password` | Super (any) / Admin (farmers only) | `target_user_id`, `new_password` |
| `delete_auth_user` | Super (any) / Admin (farmers only) | `target_user_id` — full data purge + auth delete |
| `multi_table_export` | Super | optional `limit` (max 5000) — returns JSON snapshot |

Caller must have `user_profiles.account_kind = 'staff'` and a staff `app_role`.
