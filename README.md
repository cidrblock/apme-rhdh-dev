# APME + RHDH Local (developer loop)

Test and develop Ansible Automation Portal **APME** dynamic plugins against a
local [RHDH Local](https://github.com/redhat-developer/rhdh-local) instance,
with the APME Gateway running in a Podman pod (`tox -e up`).

This is **not** a full Portal / OpenShift substitute. Use it for:

- Loading APME + self-service as RHDH dynamic plugins
- UI work against a real Gateway on `:8080`
- Validating export / `pluginConfig` wiring before Helm/OCI

For fast React composition in the monorepo, keep using `yarn start` on
`ansible-backstage-plugins@prototype/apme`. Use this repo when you care about
the **dynamic plugin** shape.

**Agents:** follow [`.cursor/skills/apme-rhdh-local/SKILL.md`](.cursor/skills/apme-rhdh-local/SKILL.md)
(and [`AGENTS.md`](AGENTS.md)). Ask Cursor to use the **apme-rhdh-local** skill
when standing this up.

---

## Happy path (other machines too)

### Prerequisites

| Tool | Notes |
|------|--------|
| Podman (or Docker) + Compose | Same as [RHDH Local](https://developers.redhat.com/blog/2025/03/31/rhdh-local-test-develop-locally-red-hat-developer-hub-using-containers) |
| Podman socket (Podman users) | `systemctl --user enable --now podman.socket` — required for `podman compose` |
| Node.js **20 or 22** + Corepack/Yarn | For plugin export (`rhdh-cli`) |
| git | |

Sibling checkouts (defaults — override in `.env`):

| Path | Repo / branch |
|------|----------------|
| `$HOME/github/ansible-backstage-plugins` | [ansible/ansible-backstage-plugins](https://github.com/ansible/ansible-backstage-plugins) @ `prototype/apme` |
| `$HOME/github/rhdh-local` | [redhat-developer/rhdh-local](https://github.com/redhat-developer/rhdh-local) |
| `$HOME/github/apme` | APME engine (for `tox -e up`) |

### One-time setup

```bash
git clone <this-repo-url> ~/github/apme-rhdh-dev
cd ~/github/apme-rhdh-dev
cp .env.example .env          # edit paths if your clones are elsewhere
systemctl --user enable --now podman.socket   # Podman users
make setup                    # clones rhdh-local if missing; wires configs
```

### Every day

```bash
# Terminal A — APME pod (Gateway :8080)
cd ~/github/apme && tox -e up

# Terminal B — export plugins + start RHDH Local
cd ~/github/apme-rhdh-dev
make sync              # export APME + self-service into rhdh-local/local-plugins
make up                # install-dynamic-plugins + start RHDH
```

Open **http://localhost:7007** → sign in as **Guest**.

APME Quality UX (prototype):

- Fleet / catalog: `/self-service/repositories/catalog`
- Quality overview: `/self-service/repositories/catalog/quality`
- Per-repo: open a Git repository entity → **APME** / Quality tab

Stop:

```bash
make down
```

---

## What `make` does

| Target | Action |
|--------|--------|
| `make setup` | Ensure `rhdh-local` exists; copy compose/app-config/plugin overrides; create `.env` |
| `make sync` | `yarn export-dynamic` for required plugins → `rhdh-local/local-plugins/` |
| `make up` | `podman compose up -d` in `rhdh-local` (Lightspeed disabled) |
| `make down` | Tear down RHDH Local containers |
| `make restart` | Restart RHDH after config-only changes (no re-export) |
| `make status` | Print paths, Gateway health, compose status |

After **plugin code** changes: `make sync && make up` (or `make sync-restart`).  
After **app-config only** changes: `make restart`.

---

## Layout

```
apme-rhdh-dev/
├── README.md
├── AGENTS.md                           # pointer for coding agents
├── Makefile
├── .env.example
├── .cursor/skills/apme-rhdh-local/     # Cursor skill: get up and running
├── configs/
│   ├── dynamic-plugins.override.yaml   # enable APME + self-service
│   ├── app-config.local.yaml           # apme.baseUrl + catalog template
│   └── compose.override.yaml           # host.containers.internal + no Lightspeed
├── catalog/
│   └── apme-register-git-repository/   # Add repository scaffolder template
└── scripts/
    ├── setup.sh
    ├── sync-plugins.sh
    ├── start.sh
    └── stop.sh
```

Configs (and the APME catalog template) are **copied** into `rhdh-local/` on
`make setup` / `make sync` / `make up` so this repo stays the source of truth.

---

## Configuration

`.env` (from `.env.example`):

| Variable | Default | Purpose |
|----------|---------|---------|
| `PLUGIN_REPO` | `$HOME/github/ansible-backstage-plugins` | Source of dynamic plugins |
| `RHDH_LOCAL` | `$HOME/github/rhdh-local` | RHDH Local checkout |
| `APME_BASE_URL` | `http://host.containers.internal:8080` | Gateway as seen **from** the RHDH container |
| `COMPOSE` | `podman compose` | Or `docker compose` |

`host.containers.internal` is the Podman host gateway. Docker Desktop usually
works with `http://host.docker.internal:8080` — set `APME_BASE_URL` accordingly.

Plugin config key is **`ansible.apme.*`** (not top-level `apme:`).

Verify Gateway on the host first:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://localhost:8080/docs
# expect 200
```

---

## Frontend hot reload (optional)

For faster FE iteration inside RHDH Local (no full re-pack each time), see
[RHDH Local plugins guide](https://github.com/redhat-developer/rhdh-local/blob/main/docs/rhdh-local-guide/plugins-guide.md)
(`rhdh-cli plugin export --dev`). Most day-to-day UI work is still faster with
`yarn start` in `PLUGIN_REPO`.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Plugins missing in UI | `make sync && make up`; check `rhdh-local/local-plugins/` |
| APME calls fail / connection refused | Confirm `tox -e up`; curl `:8080`; set `APME_BASE_URL` for your runtime |
| `rhdh-cli: command not found` | Use Node 20/22; `cd $PLUGIN_REPO && yarn install` |
| Wrong branch | `cd $PLUGIN_REPO && git checkout prototype/apme && git pull` |
| Port 7007 busy | Stop other RHDH Local / change ports in `rhdh-local` compose |
| `failed to connect … podman.sock` | `systemctl --user start podman.socket` then `make up` again |
| Blank white page | Use **http://localhost:7007** (not `127.0.0.1` — CORS). Hard-refresh. Usually duplicate API factories — our override avoids `dynamic-plugins.default.yaml` and does not register both GitRepos factories. Re-run `make up`. |
| Sign-in page only | Click **Guest → Enter** |
| Home 404 | Expected if DynamicHomePage failed to install; use **Catalog** or **/apme** / **/self-service** |
| `apiRef{ansible}` on Self-service | Ensure `AAPApis` is in self-service `apiFactories` (see `configs/dynamic-plugins.override.yaml`) |
| Template `apme-register-git-repository` 404 | `make up` after latest configs (catalog location + scaffolder module). Wait ~30s for catalog refresh, or check Catalog → Templates. |
| **RH AAP “Login failed, popup was closed”** | Self-service **Create** always calls AAP OAuth. This loop sets `ansible.apme.useStockCreateForRegister: true` so **Add repository** uses stock Create (no popup). Or open seeded Catalog entity **ansible-lightspeed**. Manual URL: `/create/templates/default/apme-register-git-repository`. Do **not** set empty `GITHUB_TOKEN=` (Backstage rejects `""`). Needs a `backstage-apme` build that supports that config key. |
| RepoUrlPicker / GitHub empty | Type owner/repo manually, or add GitHub OAuth (RHDH Local GitHub guide) / real `GITHUB_TOKEN` then `make up` |
| Catalog stuck 503 / empty-string token | Remove `GITHUB_TOKEN=` from `.env` / `rhdh-local/.env`, then `make up` |

---

## Out of scope (use Helm / Portal)

- AAP OAuth / production auth
- Portal RBAC
- Operator `ociPluginImage` install path

Those stay on OpenShift + the [Helm chart developer guide](https://github.com/ansible/ansible-rhdh-plugins/blob/main/docs/guides/helm-chart-developer-guide.md).
