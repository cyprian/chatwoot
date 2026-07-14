# Eyepic production deployment

This directory is the source-controlled deployment configuration for Eyepic's
Chatwoot installation at `https://support.eyepic.io`.

## Runtime layout

| Path | Purpose |
| --- | --- |
| `/opt/apps/chatwoot` | Clone of `cyprian/chatwoot` on the server |
| `/opt/chatwoot-runtime` | Compose file, environment variables, and backups |
| `/opt/chatwoot-runtime/.env` | Production secrets; never commit this file |
| `/opt/chatwoot-runtime/backups` | Daily compressed PostgreSQL backups |

Chatwoot is bound only to `127.0.0.1:3001`. Caddy terminates TLS and routes
`support.eyepic.io` to it. The companion CRM remains on `127.0.0.1:3000`.

## Firebase Profile inbox sidebar

This deployment builds the pinned `eyepic/chatwoot-firebase-profile` image.
It adds the **Firebase Profile** inbox integration, which lets an agent select
**Check app profile** in the conversation sidebar. The lookup gateway retrieves
the Firebase Auth user matching the contact email plus `users_credits/{uid}`
and `subscriptions/{uid}` from Firestore.

The gateway is internal-only. On the server, store the Firebase service-account
JSON at `/opt/chatwoot-runtime/firebase-service-account.json` with mode `0600`.
Set `FIREBASE_PROFILE_ENABLED=true` in `/opt/chatwoot-runtime/.env`, then run
`deployment/eyepic/bootstrap-server.sh`. Enable **Firebase Profile** for each
required inbox in Chatwoot under Settings → Integrations.

Never commit the service account. The browser does not receive it; only the
internal gateway container can read it.

## First deployment

1. Install Docker Compose v2 and Caddy on the host.
2. Clone this repository to `/opt/apps/chatwoot`.
3. Run `deployment/eyepic/bootstrap-server.sh` as root.
4. Add a daily root cron job:

   ```cron
   17 3 * * * root /opt/apps/chatwoot/deployment/eyepic/backup-chatwoot.sh >>/var/log/chatwoot-backup.log 2>&1
   ```

## Google Workspace inbox

Add these values to `/opt/chatwoot-runtime/.env`, preserving mode `0600`:

```env
GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=
GOOGLE_OAUTH_REDIRECT_URI=https://support.eyepic.io/google/callback
```

The authorized redirect URI in Google Cloud must be exactly
`https://support.eyepic.io/google/callback`. Run
`deployment/eyepic/configure-google-oauth.sh` after adding the variables.
This writes the settings to Chatwoot's installation configuration, which is
required by current Chatwoot releases for the Google email-channel flow.

## Firebase Cloud Messaging (mobile push notifications)

Chatwoot includes the FCM HTTP v1 integration in its application source. To
enable it for Eyepic's mobile app, add the Firebase project ID and the complete
Firebase service-account JSON to `/opt/chatwoot-runtime/.env`:

```env
FIREBASE_PROJECT_ID=
FIREBASE_CREDENTIALS='{"type":"service_account",...}'
```

Keep the JSON on one line and do not commit it. The service account needs
permission to send Firebase Cloud Messaging messages for the Firebase project.
Run `deployment/eyepic/configure-firebase-fcm.sh` after adding or rotating the
credentials. The script writes the values into Chatwoot's installation
configuration and restarts the processes that deliver notifications.

This is separate from the support email inbox: it sends push notifications only
when a Chatwoot client registers an `fcm` notification subscription.

## Verification

```bash
cd /opt/chatwoot-runtime
docker compose ps
curl -fsS http://127.0.0.1:3001/ >/dev/null
curl -I https://support.eyepic.io/
/opt/apps/chatwoot/deployment/eyepic/backup-chatwoot.sh
```
