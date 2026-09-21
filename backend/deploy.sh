#!/usr/bin/env bash
# One-shot Fly.io deploy. Requires: fly auth login
# Does not rotate SECRET_KEY and does not seed demo accounts.
set -euo pipefail
cd "$(dirname "$0")"

APP=food-delivery-api
DB=food-delivery-db

if ! fly apps list 2>/dev/null | grep -q "$APP"; then
  fly apps create "$APP" --org personal
fi
if ! fly postgres list 2>/dev/null | grep -q "$DB"; then
  fly postgres create --name "$DB" --org personal --region fra \
    --vm-size shared-cpu-1x --initial-cluster-size 1 --volume-size 1
  fly postgres attach "$DB" --app "$APP"
fi

if ! fly secrets list --app "$APP" | grep -q SECRET_KEY; then
  fly secrets set --app "$APP" SECRET_KEY="$(openssl rand -hex 32)" --stage
fi
# Empty allowlist is fine for a mobile-only API. Set a real origin if you add a web client.
if ! fly secrets list --app "$APP" | grep -q CORS_ORIGINS; then
  fly secrets set --app "$APP" CORS_ORIGINS="none" --stage
fi

fly deploy --app "$APP" --ha=false
echo "API health: https://$APP.fly.dev/health"
echo "Create an admin yourself — seed is blocked in prod (demo passwords)."
