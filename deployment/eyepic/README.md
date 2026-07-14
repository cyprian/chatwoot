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

## Verification

```bash
cd /opt/chatwoot-runtime
docker compose ps
curl -fsS http://127.0.0.1:3001/ >/dev/null
curl -I https://support.eyepic.io/
/opt/apps/chatwoot/deployment/eyepic/backup-chatwoot.sh
```
