#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT_REF="${SUPABASE_PROJECT_REF:-gugzmorionjucepcouyr}"
FIREBASE_KEY="${1:-${FIREBASE_SERVICE_ACCOUNT_JSON_PATH:-$ROOT/secrets/firebase-service-account.json}}"

if [[ ! -f "$FIREBASE_KEY" ]]; then
  echo "Missing Firebase service account JSON."
  echo "Download: Firebase Console → ivey-cap → Project settings → Service accounts → Generate new private key"
  echo "Then run:"
  echo "  $0 /path/to/ivey-cap-firebase-adminsdk.json"
  exit 1
fi

if ! command -v supabase >/dev/null 2>&1; then
  echo "Install Supabase CLI: https://supabase.com/docs/guides/cli"
  exit 1
fi

PUSH_SECRET="${PUSH_WEBHOOK_SECRET:-cap-push-wh-2026-agrilink-secret}"
echo "Setting Edge Function secrets on $PROJECT_REF ..."
supabase secrets set \
  PUSH_WEBHOOK_SECRET="$PUSH_SECRET" \
  FIREBASE_SERVICE_ACCOUNT_JSON="$(cat "$FIREBASE_KEY")" \
  --project-ref "$PROJECT_REF"

echo "Deploying push_notification ..."
supabase functions deploy push_notification --no-verify-jwt --project-ref "$PROJECT_REF"

echo "Applying database migration (push webhook trigger) ..."
supabase db push --linked --yes

VAULT_SQL="$(mktemp)"
trap 'rm -f "$VAULT_SQL"' EXIT
cat >"$VAULT_SQL" <<SQL
DO \$\$
DECLARE
  existing_id uuid;
BEGIN
  SELECT id INTO existing_id
  FROM vault.secrets
  WHERE name = 'cap_push_webhook_secret'
  LIMIT 1;

  IF existing_id IS NOT NULL THEN
    PERFORM vault.update_secret(existing_id, '$PUSH_SECRET', 'cap_push_webhook_secret', 'Push webhook auth for push_notification edge function');
  ELSE
    PERFORM vault.create_secret('$PUSH_SECRET', 'cap_push_webhook_secret', 'Push webhook auth for push_notification edge function');
  END IF;
END \$\$;
SQL

echo "Storing webhook secret in Supabase Vault ..."
if command -v supabase >/dev/null 2>&1 && supabase db query --help >/dev/null 2>&1; then
  supabase db query --linked --yes -f "$VAULT_SQL"
elif npx --yes supabase@2.108.0 db query --linked --yes -f "$VAULT_SQL"; then
  :
else
  echo "Paste this in Supabase SQL Editor:"
  cat "$VAULT_SQL"
  exit 0
fi

echo "Done. Push pipeline:"
echo "  user_notifications INSERT → pg_net → push_notification → FCM"
echo "Verify: enable push in app, confirm fcm_token in user_profiles, trigger a notification."
