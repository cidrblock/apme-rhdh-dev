# Pitfalls — APME RHDH Local

## Blank white page

- Use **http://localhost:7007**, not `127.0.0.1`.
- Hard-refresh the browser.
- Usually duplicate API factories: do **not** include `dynamic-plugins.default.yaml`
  and do **not** register both Self-service `defaultGitRepositoriesExtensionsApiFactory`
  and APME `gitRepositoriesExtensionsApiFactory`.
- Do not mount Self-service `LandingPage` at `/` (collides with DynamicHomePage).
- Fix: restore `configs/dynamic-plugins.override.yaml` from this repo, then `make up`.

## Sign-in / Home

- Sign-in page only → **Guest → Enter**.
- Home 404 → use Catalog or `/self-service/repositories/catalog` (DynamicHomePage may be absent).
- `make react`: use `/self-service/repositories/catalog` or `/quality` — **not** `/apme`.

## RH AAP “Login failed, popup was closed”

Self-service **Create** always calls AAP OAuth. This repo sets
`ansible.apme.useStockCreateForRegister: true` so **Add repository** uses stock
Create. Requires a `backstage-apme` export that supports that key; then
`make sync && make up`.

Fallback without the flag:

- Stock Create: `/create/templates/default/apme-register-git-repository`
- Or open seeded Catalog entity **ansible-lightspeed**

Do not configure real AAP OAuth for the default loop unless the user asks.

## Catalog 503 / empty GitHub token

Backstage rejects `integrations.github[].token: ""`.

- Remove `GITHUB_TOKEN=` from `.env` and `rhdh-local/.env` (omit the var).
- `make up` again.
- Optional: set a **real** PAT, then `make up` (scripts append integrations only when set).

## Template or seed missing

After config changes: `make up`, wait ~30s for catalog refresh.

- Template: `Template:default/apme-register-git-repository`
- Seed: `Component:default/ansible-lightspeed-github-manual` (title ansible-lightspeed)

## `catalog-backend-module-rhaap` / `ansible.rhaap`

Loading that module requires `ansible.rhaap.baseUrl` + `token` (stub OK).
This repo’s `configs/app-config.local.yaml` already stubs them (`127.0.0.1:9`).
Do not remove the stub while the module is enabled in the override.

## “A scan is already in progress”

A prior `check`/`remediate` is still active (often remediate stuck in
`awaiting_approval`). Cancel via Gateway:

```bash
curl -sS http://127.0.0.1:8080/api/v1/operations/active
# note project_id
curl -sS -X POST \
  "http://127.0.0.1:8080/api/v1/projects/<project_id>/operation/cancel"
```

Then retry Scan in the UI.

## Podman / ports

- `failed to connect … podman.sock` → `systemctl --user start podman.socket`
- Port 7007 busy → stop other RHDH Local or change compose ports
- Gateway connection refused from UI → `tox -e up` in `apme`; verify
  `APME_BASE_URL` (`host.containers.internal` Podman / `host.docker.internal` Docker)

## Plugin export / which make target

- Node **20 or 22**; `cd $PLUGIN_REPO && yarn install` if `rhdh-cli` missing
- Wrong branch → `prototype/apme`
- Everyday UI → `make react` → http://localhost:3001 (not sync-restart)
- `EADDRINUSE :3000` on `make react` → you’re on an old script; pull latest
  (`make react` uses **3001/7008**). Native APME dashboard keeps **:3000**.
- `make react` UI 404 / every `/api/*` 404 / “Backend has not started yet” →
  backend failed. Common cause: `better-sqlite3` built for another Node ABI
  (Node 20 vs 22). `make react` rebuilds it; or
  `cd $PLUGIN_REPO && yarn rebuild better-sqlite3`. Also need AAP/auth stubs
  (script sets them; see `configs/app-config.react.yaml`).
- `make react` 401 / `ERR_JWKS_NO_MATCHING_KEY` after restart → browser still has
  an old Guest JWT. **Clear site data** for `http://localhost:3001` (or Sign out)
  and Guest again. `make react` now persists `BACKEND_SECRET` /
  `AUTH_SIGNING_KEY` in this repo’s `.env` so keys stay stable.
- `/api/catalog/ansible/sync/status` 403/404 without real AAP → expected noise
  from self-service polling; not the cause of page 404s.
- FE in RHDH without recreate → `make up-dev` once, then `make sync-dev` + refresh
- Full dynamic-plugin check → `make sync-restart`
- `make sync-dev` while compose mode is `normal` → start with `make up-dev` first
- `make up-dev` without prior `make sync` → run `make sync` once for backends
