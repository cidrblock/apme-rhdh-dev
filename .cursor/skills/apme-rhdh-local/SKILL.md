---
name: apme-rhdh-local
description: >-
  Stand up and operate the APME + RHDH Local developer loop (dynamic portal
  plugins against a local APME Gateway). Use when the user opens apme-rhdh-dev,
  asks to run APME in RHDH Local, sync/export portal plugins, fix blank page /
  Guest login / AAP popup / scan stuck, or get another developer up and running
  on this workspace.
---

# APME + RHDH Local

This repo is the **source of truth** for a repeatable local loop: export Portal
APME plugins → load them in [RHDH Local](https://github.com/redhat-developer/rhdh-local)
→ talk to APME Gateway on `:8080`.

It is **not** full Ansible Automation Portal (no real AAP OAuth/RBAC) and **not**
the native APME SPA. For native UI work, use the `apme` frontend. For fast React
iteration without dynamic export, use `yarn start` in `PLUGIN_REPO`.

Human docs: [README.md](../../../README.md). Prefer `make` targets over calling
scripts by hand.

## Hard rules

1. Work from this repo root (`apme-rhdh-dev`). Do not invent a parallel loop under
   `ansible-rhdh-plugins` or `apme` unless the user asks.
2. Use **`make setup` / `sync` / `up` / `down` / `restart` / `status`** only.
3. Open the UI at **http://localhost:7007** (not `127.0.0.1` — CORS / `app.baseUrl`).
4. Sign in as **Guest**.
5. Config key is **`ansible.apme.*`**, never top-level `apme:`.
6. Never set empty `GITHUB_TOKEN=` — omit the var or use a real PAT.
7. Do not `include: dynamic-plugins.default.yaml` and do not register both
   Self-service and APME GitRepos `apiFactories` (blank white page).
8. APME Gateway must be up before `make up` (`curl -sS -o /dev/null -w '%{http_code}\n' http://localhost:8080/docs` → `200`).

## Sibling checkouts (defaults)

| Path | Role |
|------|------|
| `$HOME/github/ansible-backstage-plugins` @ `prototype/apme` | Plugin source (`PLUGIN_REPO`) |
| `$HOME/github/rhdh-local` | RHDH Local runtime (`RHDH_LOCAL`) |
| `$HOME/github/apme` | Engine pod — `tox -e up` → Gateway `:8080` |

Override paths in `.env` (from `.env.example`).

## Get up and running (agent checklist)

Copy and track:

```
Progress:
- [ ] .env exists (cp .env.example .env); paths sane
- [ ] Podman socket (Podman users): systemctl --user enable --now podman.socket
- [ ] make setup
- [ ] APME Gateway: cd $HOME/github/apme && tox -e up  (host :8080)
- [ ] make sync
- [ ] make up
- [ ] Browser: http://localhost:7007 → Guest
- [ ] Smoke: /apme or /self-service/repositories/catalog/quality
```

### One-time

```bash
cd /path/to/apme-rhdh-dev
cp -n .env.example .env   # edit PLUGIN_REPO / RHDH_LOCAL / APME_BASE_URL if needed
systemctl --user enable --now podman.socket   # Podman
make setup
```

### Daily

```bash
# Terminal A — Gateway
cd "${HOME}/github/apme" && tox -e up

# Terminal B — plugins + RHDH
cd /path/to/apme-rhdh-dev
make sync
make up
```

### After changes

| Change | Command |
|--------|---------|
| Plugin source in `PLUGIN_REPO` | `make sync && make up` (or `make sync-restart`) |
| `configs/*` / catalog only | `make restart` (or `make up` — force-recreates) |
| Stop RHDH | `make down` |

`make status` prints paths, Gateway health, and compose state.

## Useful URLs

| What | URL |
|------|-----|
| RHDH | http://localhost:7007 |
| Quality fleet | http://localhost:7007/self-service/repositories/catalog/quality |
| Seeded repo (no Add flow) | Catalog → **ansible-lightspeed** → APME / Quality |
| Add repo **without** AAP popup | http://localhost:7007/create/templates/default/apme-register-git-repository |
| Gateway docs (host) | http://localhost:8080/docs |

## Scope boundaries

**In scope:** dynamic plugin export/load, Guest UI, Quality against real Gateway,
scaffolder register template, seed git-repository entity.

**Out of scope:** AAP OAuth, Portal RBAC, Operator/OCI plugin install, native APME
SPA feature parity. Point users at Helm/Portal docs for those.

## Pitfalls (read when stuck)

See [pitfalls.md](pitfalls.md) for blank page, AAP login popup, stuck scans,
catalog 503, and `ansible.rhaap` stub requirements.

## Agent communication

- Run commands; do not only paste the README.
- After `make up`, wait until RHDH is ready (`make status` / Guest refresh works)
  before declaring success.
- If `PLUGIN_REPO` is on the wrong branch: `git checkout prototype/apme && git pull`.
- Prefer fixing configs in **this** repo; they are copied into `rhdh-local/` on
  setup/sync/up — do not treat `rhdh-local/configs/` as source of truth.
