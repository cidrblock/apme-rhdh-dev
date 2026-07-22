# Agent notes — apme-rhdh-dev

This workspace stands up **APME Portal dynamic plugins** in **RHDH Local** against a
local APME Gateway.

## Skill (read first)

When helping a user get running, sync plugins, or debug this loop, read and
follow:

**[`.cursor/skills/apme-rhdh-local/SKILL.md`](.cursor/skills/apme-rhdh-local/SKILL.md)**

Pitfalls: [`.cursor/skills/apme-rhdh-local/pitfalls.md`](.cursor/skills/apme-rhdh-local/pitfalls.md)

Human overview: [`README.md`](README.md)

## Quick commands

```bash
make setup          # one-time
# APME Gateway: cd ~/github/apme && tox -e up
make sync && make up
make status
make down
```

UI: **http://localhost:7007** (Guest). Not `127.0.0.1`.
