#!/bin/bash
set -euo pipefail

RUNTIME_DIR=/opt/chatwoot-runtime
CALLBACK_URL=https://support.eyepic.io/google/callback

cd "$RUNTIME_DIR"
set -a
. ./.env
set +a

: "${GOOGLE_OAUTH_CLIENT_ID:?set GOOGLE_OAUTH_CLIENT_ID in $RUNTIME_DIR/.env}"
: "${GOOGLE_OAUTH_CLIENT_SECRET:?set GOOGLE_OAUTH_CLIENT_SECRET in $RUNTIME_DIR/.env}"

docker compose exec -T rails bundle exec rails runner '
  {
    "GOOGLE_OAUTH_CLIENT_ID" => ENV.fetch("GOOGLE_OAUTH_CLIENT_ID"),
    "GOOGLE_OAUTH_CLIENT_SECRET" => ENV.fetch("GOOGLE_OAUTH_CLIENT_SECRET"),
    "GOOGLE_OAUTH_REDIRECT_URI" => "https://support.eyepic.io/google/callback",
  }.each do |key, value|
    InstallationConfig.where(name: key).first_or_create.update!(value: value, locked: false)
  end
  GlobalConfig.clear_cache
'

docker compose up -d --force-recreate rails sidekiq
