#!/bin/bash
set -euo pipefail

RUNTIME_DIR=/opt/chatwoot-runtime

cd "$RUNTIME_DIR"
set -a
. ./.env
set +a

: "${FIREBASE_PROJECT_ID:?set FIREBASE_PROJECT_ID in $RUNTIME_DIR/.env}"
: "${FIREBASE_CREDENTIALS:?set FIREBASE_CREDENTIALS in $RUNTIME_DIR/.env}"

docker compose exec -T rails bundle exec rails runner '
  {
    "FIREBASE_PROJECT_ID" => ENV.fetch("FIREBASE_PROJECT_ID"),
    "FIREBASE_CREDENTIALS" => ENV.fetch("FIREBASE_CREDENTIALS"),
  }.each do |key, value|
    InstallationConfig.where(name: key).first_or_create.update!(value: value, locked: false)
  end
  GlobalConfig.clear_cache
'

docker compose up -d --force-recreate rails sidekiq
