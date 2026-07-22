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
- Home 404 → use Catalog, `/apme`, or `/self-service` (DynamicHomePage may be absent).

## RH AAP “Login failed, popup was closed”

Self-service **Create** always calls AAP OAuth. For local APME without AAP:

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

## Plugin export

- Node **20 or 22**; `cd $PLUGIN_REPO && yarn install` if `rhdh-cli` missing
- Wrong branch → `prototype/apme`
- After plugin code changes → `make sync && make up` (plain `up` alone is not enough)
