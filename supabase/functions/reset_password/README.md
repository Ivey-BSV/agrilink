# Reset Password Edge Function

This function allows password reset using a 4-digit code (hardcoded as `1234`). The app sends: `usernameOrEmail` (or `email`), `code`, `new_password`.

## Deploy

From the project root (with [Supabase CLI](https://supabase.com/docs/guides/cli) installed and linked):

```bash
supabase functions deploy reset_password
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are set automatically in the Supabase dashboard for deployed functions.

## Troubleshooting

- **`Failed to send a request to the Edge Function` / network errors (web or app)**  
  - **Redeploy** this function after pulling updates (CORS + `OPTIONS` support for browser clients).  
  - Confirm the function exists: Dashboard → **Edge Functions** → `reset_password`.  
  - The web dashboard and mobile app call `invoke` with the **anon** `Authorization` header so a stale or expired **user** session JWT does not block the gateway.

- **404 / “not found”**  
  - The function is not deployed to this Supabase project, or the project URL / anon key in the app does not match the project where the function lives.

## Change the code

Edit the `RESET_CODE` constant in `index.ts` (and in the app: `AuthProvider._resetCode`, `dashboard/src/lib/web-auth.ts` `RESET_PASSWORD_CODE`, and the reset UI copy if you want them in sync). Redeploy the function after changing.
