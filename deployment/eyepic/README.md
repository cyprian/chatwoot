# Eyepic production deployment

Production: https://support.eyepic.io. Source: `/opt/apps/chatwoot`.
Runtime configuration, credentials and volumes: `/opt/chatwoot-runtime`.
Rails binds `127.0.0.1:3001`; Caddy provides TLS. The neighboring CRM uses port 3000.

## Reproducible custom image

The Dockerfile pins upstream Chatwoot **4.18.0 by digest** for dependencies and
system libraries. It installs the complete merged Eyepic application source and
compiles its assets with the upstream lockfiles. Firebase Profile, Eye.Photo,
OpenAI text/email translation, Hub egress controls, custom per-inbox Slack and
production favicon assets are tracked in source. No build-time source patches
or copies from an older development version are used.

Set these values in the protected runtime `.env`:

```env
CHATWOOT_VERSION=v4.18.0
EYEPIC_REVISION=<full tested Git commit>
CHATWOOT_IMAGE=eyepic/chatwoot-firebase-profile:v4.18.0-<full tested Git commit>
CHATWOOT_BUILD_CONTEXT=/opt/apps/chatwoot
```

Build once and run Rails and Sidekiq from the same immutable image. Changing
`CHATWOOT_VERSION` alone does not select or rebuild an image. Record the image
ID and upstream digest with each deployment.

## Integrations

- Firebase Profile uses existing per-inbox `firebase_profile` hooks. Its internal
  gateway reads Firebase Auth and Firestore credits/subscriptions. Preserve the
  gateway token and `/opt/chatwoot-runtime/firebase-service-account.json` (0600).
  Keep `FIREBASE_PROFILE_ENABLED=true` and the Compose `firebase-profile` profile.
- Eye.Photo uses per-inbox `eye_photo` hooks; its API key is held in the hook's
  token column. Lookups enforce the conversation's account and inbox permissions.
- Translation uses the account's enabled OpenAI integration and caches English
  translations while preserving original text/email views and the AI menu action.
- Custom Slack uses persisted workspace connections, inbox configurations and
  delivery records. Preserve database and encryption keys. Its OAuth callback is
  `/api/v1/slack_workspace_oauth/callback` on the production hostname.
- Hub sync, registration, telemetry and Hub-mediated push remain opt-in via
  `CHATWOOT_HUB_ENABLED`; unset defaults to disabled.
- Google Workspace requires `GOOGLE_OAUTH_CLIENT_ID`,
  `GOOGLE_OAUTH_CLIENT_SECRET`, and
  `GOOGLE_OAUTH_REDIRECT_URI=https://support.eyepic.io/google/callback`.
  `configure-google-oauth.sh` reconciles installation settings when configuring
  the integration; existing settings are preserved on upgrade.

Never commit `.env`, OAuth tokens, encryption keys or the Firebase service account.

## Upgrade procedure

1. Preserve the running image and protected runtime configuration. Snapshot the
   database, attachment volume and Redis, and keep a recovery copy off-host.
2. Restore a recent database/attachment snapshot into separate staging services.
   Block external egress and do not run staging workers against customer channels.
3. Build the candidate, run existing Ruby/Vue tests, and migrate the staging copy
   using `bundle exec rails db:chatwoot_prepare`. Check integration settings,
   encrypted token readability, account/message counts and attachment storage.
4. Prove the pre-upgrade snapshot restores and the retained old image boots.
5. Put only support in maintenance, stop writers and gracefully stop workers,
   then take final consistent recovery snapshots. Keep CRM available.
6. Migrate once with the tested candidate; start Rails/Sidekiq from the same image,
   preserve the Firebase profile, and verify local/public HTTP, authentication,
   assets, worker queues and custom integration endpoints before reopening.
7. Monitor a complete scheduled email-polling cycle and reconcile inbound retries.

After a schema change, rollback requires restoring the matching database,
attachments, queue state and configuration before using the retained old image.
Do not blindly restore an old database after accepting new customer traffic.

## Verification and backup

```bash
cd /opt/chatwoot-runtime
docker compose ps
curl -fsS http://127.0.0.1:3001/ >/dev/null
curl -fsS https://support.eyepic.io/ >/dev/null
/opt/apps/chatwoot/deployment/eyepic/backup-chatwoot.sh
```

The daily backup script covers PostgreSQL. Attachment, Redis, credentials and
image recovery artifacts must also be captured for release rollback. Keep its
existing daily 03:17 UTC cron job and off-host recovery storage.
