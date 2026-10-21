#!/usr/bin/env sh
set -eu

# Registers a "pbsmidata-real" Keycloak identity provider pointing at the real MiData
# (Hitobito) instance at https://pbs.puzzle.ch, reusing the same OAuth app credentials
# eCamp's own login already uses in local dev (api/.env.dev.local).
#
# Keycloak's realm-import JSON (realm-export.json) does NOT support ${env.VAR}-style
# substitution -- confirmed empirically, it stores such placeholders as a literal string.
# So the real client secret can't live there without hardcoding it into a committed file.
# Instead, this script reads it straight out of the gitignored api/.env.dev.local and
# POSTs it directly to Keycloak's Admin REST API, after realm import. It never writes the
# secret to disk anywhere in this repo.
#
# Run after `docker compose up -d keycloak`. Keycloak's dev-mode storage is ephemeral, so
# re-run this every time the `keycloak` container is recreated (e.g. after
# `docker compose rm -sf keycloak`).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../../api/.env.dev.local"
KEYCLOAK_BASE="http://localhost:3000/keycloak"

if [ ! -f "$ENV_FILE" ]; then
  echo "Not found: $ENV_FILE -- ask a teammate for the real pbsmidata OAuth credentials." >&2
  exit 1
fi

CLIENT_ID=$(grep '^OAUTH_PBSMIDATA_CLIENT_ID=' "$ENV_FILE" | cut -d= -f2- | tr -d '"')
CLIENT_SECRET=$(grep '^OAUTH_PBSMIDATA_CLIENT_SECRET=' "$ENV_FILE" | cut -d= -f2- | tr -d '"')

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "OAUTH_PBSMIDATA_CLIENT_ID/OAUTH_PBSMIDATA_CLIENT_SECRET not set in $ENV_FILE" >&2
  exit 1
fi

ADMIN_TOKEN=$(curl -s "$KEYCLOAK_BASE/realms/master/protocol/openid-connect/token" \
  -d grant_type=password -d client_id=admin-cli -d username=admin -d password=admin \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['access_token'])")

# Delete-then-recreate, so re-running this script after editing it actually applies the
# change, instead of just reporting "already exists" against stale config.
curl -s -o /dev/null -X DELETE "$KEYCLOAK_BASE/admin/realms/ecamp/identity-provider/instances/pbsmidata-real" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

HTTP_STATUS=$(curl -s -o /tmp/pbsmidata-real-idp-response.json -w '%{http_code}' \
  -X POST "$KEYCLOAK_BASE/admin/realms/ecamp/identity-provider/instances" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "alias": "pbsmidata-real",
    "displayName": "PBS MiData (real, pbs.puzzle.ch)",
    "providerId": "oidc",
    "enabled": true,
    "trustEmail": true,
    "storeToken": false,
    "config": {
      "clientId": "'"$CLIENT_ID"'",
      "clientSecret": "'"$CLIENT_SECRET"'",
      "clientAuthMethod": "client_secret_post",
      "syncMode": "IMPORT",
      "defaultScope": "name email",
      "useJwksUrl": "true",
      "validateSignature": "true",
      "authorizationUrl": "https://pbs.puzzle.ch/oauth/authorize",
      "tokenUrl": "https://pbs.puzzle.ch/oauth/token",
      "userInfoUrl": "https://pbs.puzzle.ch/oauth/userinfo",
      "jwksUrl": "https://pbs.puzzle.ch/oauth/discovery/keys",
      "issuer": "https://pbs.puzzle.ch"
    }
  }')

if [ "$HTTP_STATUS" = "201" ]; then
  echo "Registered identity provider 'pbsmidata-real' in the ecamp realm."
else
  echo "Unexpected response ($HTTP_STATUS):" >&2
  cat /tmp/pbsmidata-real-idp-response.json >&2
  exit 1
fi
