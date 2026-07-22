# APME + RHDH Local developer loop — see README.md

.PHONY: help setup sync up down restart sync-restart status

help:
	@echo "APME RHDH Local — common targets:"
	@echo "  make setup         One-time: .env, clone deps if needed, wire configs"
	@echo "  make sync          Export APME + self-service into rhdh-local/local-plugins"
	@echo "  make up            Start RHDH Local"
	@echo "  make down          Stop RHDH Local"
	@echo "  make restart       Restart rhdh (app-config only)"
	@echo "  make sync-restart  sync + up (after plugin code changes)"
	@echo "  make status        Paths / Gateway / compose"

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
