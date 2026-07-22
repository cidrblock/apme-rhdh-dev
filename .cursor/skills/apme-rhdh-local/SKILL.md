---
name: apme-rhdh-local
description: >-
  Stand up and operate the APME + RHDH Local developer loop (dynamic portal
  plugins against a local APME Gateway). Use when the user opens apme-rhdh-dev,
  asks to run APME in RHDH Local, sync/export portal plugins, make react /
  up-dev / sync-dev, fix blank page / Guest login / AAP popup / scan stuck, or
  get another developer up and running on this workspace.
---

# APME + RHDH Local

This repo is the **source of truth** for a repeatable local loop: Portal APME
plugins → RHDH Local and/or monorepo `yarn start` → APME Gateway on `:8080`.

It is **not** full Ansible Automation Portal (no real AAP OAuth/RBAC) and **not**
the native APME SPA.

Human docs: [README.md](../../../README.md). Prefer `make` targets over calling
scripts by hand.

## Pick a loop (important)

| Goal | Commands |
|------|----------|
| **Everyday APME UI** (default — HMR) | Gateway → `make react` |
| **UI as dynamic plugin in RHDH** | `make sync` → `make up-dev` → edit → `make sync-dev` → refresh |
| **Full export / ship-shape** | `make sync-restart` |

Most APME plugin work is React → prefer **`make react`**. Use RHDH loops when
validating dynamic-plugin load / `pluginConfig`.

## Hard rules

1. Work from this repo root (`apme-rhdh-dev`).
2. Use **`make`** targets only (`react`, `setup`, `sync`, `up`, `up-dev`,
   `sync-dev`, `down`, `restart`, `status`, `sync-restart`).
3. RHDH UI: **http://localhost:7007** (not `127.0.0.1`). Guest sign-in.
4. Config key is **`ansible.apme.*`**, never top-level `apme:`.
5. Never set empty `GITHUB_TOKEN=` — omit the var or use a real PAT.
6. Do not `include: dynamic-plugins.default.yaml` and do not register both
   Self-service and APME GitRepos `apiFactories` (blank white page).
7. Gateway for real scans: `curl … http://localhost:8080/docs` → `200`.

## Sibling checkouts (defaults)

| Path | Role |
|------|------|
| `$HOME/github/ansible-backstage-plugins` @ `prototype/apme` | Plugin source (`PLUGIN_REPO`) |
| `$HOME/github/rhdh-local` | RHDH Local runtime (`RHDH_LOCAL`) |
| `$HOME/github/apme` | Engine pod — `tox -e up` → Gateway `:8080` |

## Get up and running

```
Progress:
- [ ] .env exists; paths sane
- [ ] Podman socket (if Podman): systemctl --user enable --now podman.socket
- [ ] make setup
- [ ] APME Gateway: cd $HOME/github/apme && tox -e up
- [ ] Choose loop: make react  OR  (make sync && make up / up-dev)
```

### One-time

```bash
cd /path/to/apme-rhdh-dev
cp -n .env.example .env
systemctl --user enable --now podman.socket   # Podman
make setup
```

### Everyday UI (`make react`)

```bash
cd "${HOME}/github/apme" && tox -e up          # Terminal A
cd /path/to/apme-rhdh-dev && make react        # Terminal B — yarn start
```

### RHDH full path

```bash
make sync && make up
# browser http://localhost:7007 → Guest
```

### RHDH FE --dev path (no recreate each edit)

```bash
make sync                 # once (backends)
make up-dev               # once per session
# edit FE…
make sync-dev             # then hard-refresh browser
```

`SYNC_DEV_PLUGINS` defaults to `backstage-apme`. Override:
`SYNC_DEV_PLUGINS="backstage-apme self-service" make sync-dev`.

### After changes

| Change | Command |
|--------|---------|
| Everyday UI | already live via `make react` HMR |
| FE in RHDH (up-dev session) | `make sync-dev` + refresh |
| Backend plugins / full check | `make sync-restart` |
| `configs/*` only | `make restart` |
| Stop RHDH | `make down` |

## Useful URLs

| What | URL |
|------|-----|
| RHDH | http://localhost:7007 |
| Quality fleet | http://localhost:7007/self-service/repositories/catalog/quality |
| Seeded repo | Catalog → **ansible-lightspeed** → APME / Quality |
| Stock Create (no AAP) | http://localhost:7007/create/templates/default/apme-register-git-repository |
| Gateway docs | http://localhost:8080/docs |

## Pitfalls

See [pitfalls.md](pitfalls.md).

## Agent communication

- Run commands; do not only paste the README.
- Prefer **`make react`** when the user is doing UI work unless they ask for RHDH.
- After `make up` / `up-dev`, wait until Guest works before declaring success.
- Config source of truth is **this** repo (copied into `rhdh-local/`).
