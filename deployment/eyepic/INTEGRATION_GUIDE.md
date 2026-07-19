# Building an Eyepic Chatwoot inbox integration

Use this guide when adding a support-agent tool to the Chatwoot conversation
sidebar, following the Firebase Profile integration as the reference design.

The intended result is a small, first-class Chatwoot integration: agents enable
it per inbox in **Settings → Integrations**, then use it beside a conversation.
The browser receives only the information an agent needs. Credentials and
private system access stay in an internal service.

## Architecture

```text
Agent in Chatwoot sidebar
        │
        ▼
Chatwoot dashboard component
        │ authenticated Chatwoot API request
        ▼
Chatwoot controller + service
        │ bearer token on the private Docker network
        ▼
Integration gateway container
        │ service account / API key
        ▼
Private system (Firebase, billing, product database, etc.)
```

The Firebase Profile implementation is the working example:

| Part | Reference file |
| --- | --- |
| Version-pinned Chatwoot overlay | `Dockerfile.chatwoot-firebase-profile` |
| Chatwoot source changes | `chatwoot-firebase-profile.patch` |
| Private lookup service | `firebase-profile-gateway/server.mjs` |
| Gateway container | `firebase-profile-gateway/Dockerfile` |
| Runtime services and secret mount | `docker-compose.yml` |

## 1. Define the agent experience and data contract

Start with a narrow question an agent needs answered, such as “What plan is
this customer on?” or “What is the latest order status?” Decide:

- the conversation/contact value used as the lookup key, normally email;
- the exact fields agents may see;
- the empty, not-found, and upstream-error states; and
- which inboxes should expose the feature.

Keep the gateway response deliberately small and stable. Do not return full
customer records simply because the internal system has them.

## 2. Build a private gateway

Create a directory such as `deployment/eyepic/<integration>-gateway/` with a
Dockerfile, `package.json`, and service implementation. Its API should have:

- `GET /healthz` for deployment checks;
- one authenticated lookup endpoint, for example `POST /v1/profile`;
- a `Bearer` token checked with a constant secret from the runtime environment;
- validation of all request values; and
- explicit response codes for invalid input, no result, and upstream failure.

The gateway must have no host port. Add it to the Docker Compose network only.
Mount third-party credentials as a Compose secret or read-only file. Never put
them in the repository, browser bundle, Chatwoot database, or API response.

For a new integration, give the external service identity the minimum scope:
read-only access to only the required records wherever possible.

## 3. Add the Chatwoot server endpoint

The dashboard should call Chatwoot, not the private gateway directly. Add:

1. a controller under `app/controllers/api/v1/accounts/integrations/`;
2. a service that validates the current account/inbox and calls the gateway;
3. a route under the authenticated account API namespace; and
4. request specs covering successful, missing, unauthorised, and failed
   lookups.

The Firebase patch contains `FirebaseProfileController` and
`FirebaseProfileGateway` as examples. The controller keeps Chatwoot's normal
authentication and account isolation in front of the gateway.

Use an environment flag such as `MY_INTEGRATION_ENABLED` so a disabled service
does not appear usable. Store the gateway URL and bearer token in the runtime
`.env`; do not hard-code them in the patch.

## 4. Add the sidebar UI and inbox integration registration

The frontend portion normally needs:

1. an API client in `app/javascript/dashboard/api/integrations/`;
2. a focused Vue component in
   `app/javascript/dashboard/components/widgets/conversation/`;
3. a sidebar item in `ContactPanel.vue` and the default sidebar order in
   `useUISettings.js`;
4. translations in the English locale files; and
5. an entry in `config/integration/apps.yml` plus the integration settings
   components, so the feature can be enabled per inbox.

Always handle a contact without an email, no matching record, loading, and
errors in the component. Do not make the lookup automatically on every
conversation load unless the product need justifies it; Firebase Profile uses
an explicit **Check app profile** action.

## 5. Package the Chatwoot changes as a pinned overlay

The production image is based on the official version pinned by
`CHATWOOT_VERSION` (currently `v4.14.0`). Keep custom Chatwoot application
changes in `<integration>.patch` and apply them in an overlay Dockerfile.

```dockerfile
FROM chatwoot/chatwoot:${CHATWOOT_VERSION}
COPY deployment/eyepic/<integration>.patch /tmp/integration.patch
RUN patch --batch --forward -p1 -d /app < /tmp/integration.patch
RUN bundle exec rake assets:precompile
```

The production `Dockerfile.chatwoot-firebase-profile` is the fuller working
template. It also copies the integration icon and installs the JavaScript
dependencies needed for asset compilation.

When upgrading Chatwoot, test the patch against the new base image before
changing `CHATWOOT_VERSION`. Resolve patch conflicts in a temporary Chatwoot
checkout, regenerate the patch, rebuild, and test the sidebar manually.

## 6. Add the gateway to Compose safely

Add a named Compose profile for the optional gateway. The Firebase profile is
enabled with `--profile firebase-profile`, which lets standard Chatwoot start
without the service when its feature flag is false.

For each new gateway add:

- a profile name;
- build context under `deployment/eyepic/`;
- secret-file mount for external credentials;
- required runtime variables, including a generated bearer token; and
- `restart: unless-stopped`.

Update `bootstrap-server.sh` to initialise non-secret defaults only. Existing
runtime values must be retained on future deploys.

## 7. Deploy and enable

1. Add the third-party credential file to `/opt/chatwoot-runtime/` with mode
   `0600`.
2. Add or update the integration’s non-secret settings in
   `/opt/chatwoot-runtime/.env` (also mode `0600`).
3. Deploy from `/opt/apps/chatwoot` with
   `deployment/eyepic/bootstrap-server.sh`.
4. Confirm the gateway health endpoint from inside its container.
5. In Chatwoot, enable the integration for the intended inboxes.
6. Test with a contact that has data, a contact with no matching data, and a
   contact without the lookup key.

## Verification checklist

```bash
cd /opt/chatwoot-runtime
docker compose ps
docker compose exec -T <gateway-service> wget -qO- http://127.0.0.1:8080/healthz
curl -fsSL -o /dev/null -w '%{http_code}\n' https://support.eyepic.io/
curl -fsS -o /dev/null -w '%{http_code}\n' https://crm.eyepic.io/
```

Also verify in the UI that the integration is absent or disabled for unrelated
inboxes. Finally, inspect the gateway response in browser developer tools to
ensure no credentials or unnecessary customer data are exposed.

## When not to use this pattern

Use a Chatwoot Dashboard App instead when an iframe-based, independently hosted
tool is sufficient and it does not require custom server-side Chatwoot routes.
Use this overlay pattern when the agent experience needs a native conversation
sidebar widget, per-inbox integration settings, or protected access to a
private backend through Chatwoot.
