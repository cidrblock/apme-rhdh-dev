# Agent notes — apme-rhdh-dev

This workspace stands up **APME Portal dynamic plugins** against a local APME
Gateway — either via **monorepo React** (`make react`) or **RHDH Local**.

## Skill (read first)

**[`.cursor/skills/apme-rhdh-local/SKILL.md`](.cursor/skills/apme-rhdh-local/SKILL.md)**

Pitfalls: [`.cursor/skills/apme-rhdh-local/pitfalls.md`](.cursor/skills/apme-rhdh-local/pitfalls.md)

Human overview: [`README.md`](README.md)

## Quick commands

```bash
make setup

# Everyday UI (preferred for most APME FE work)
# Gateway: cd ~/github/apme && tox -e up
make react

# RHDH dynamic plugins
make sync && make up
# FE --dev loop: make up-dev → edit → make sync-dev → refresh

make status
make down
```

RHDH UI: **http://localhost:7007** (Guest). Not `127.0.0.1`.
