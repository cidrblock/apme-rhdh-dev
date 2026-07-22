# APME + RHDH Local developer loop — see README.md

.PHONY: help setup sync up down restart sync-restart status react up-dev sync-dev

help:
	@echo "APME RHDH Local — pick a loop:"
	@echo ""
	@echo "  Everyday UI (fastest HMR):"
	@echo "    make react           yarn start in PLUGIN_REPO"
	@echo ""
	@echo "  Dynamic plugins in RHDH:"
	@echo "    make sync            Export plugins → local-plugins (once / backends)"
	@echo "    make up              Start RHDH (full install path)"
	@echo "    make sync-restart    sync + up (after plugin changes, full recreate)"
	@echo "    make up-dev          Start RHDH with FE --dev mount (once per session)"
	@echo "    make sync-dev        Re-export FE → dynamic-plugins-root; refresh browser"
	@echo ""
	@echo "  Other:"
	@echo "    make setup           One-time: .env, clones, wire configs"
	@echo "    make down            Stop RHDH Local"
	@echo "    make restart         Restart rhdh (app-config only)"
	@echo "    make status          Paths / Gateway / compose"

setup:
	./scripts/setup.sh

sync:
	./scripts/sync-plugins.sh

up:
	./scripts/start.sh

down:
	./scripts/stop.sh

restart:
	./scripts/restart.sh

sync-restart: sync up

status:
	./scripts/status.sh

# Fast React HMR in the plugin monorepo (not RHDH).
react:
	./scripts/react.sh

# RHDH Local FE --dev loop (export + refresh, no recreate).
up-dev:
	./scripts/start-dev.sh

sync-dev:
	./scripts/sync-dev.sh
