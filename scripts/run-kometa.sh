#!/bin/bash
# Triggers a Kometa run (one-shot container).
# Called by launchd every 4 hours or manually.

set -euo pipefail

DOCKER_BIN="$(command -v docker || echo /opt/homebrew/bin/docker)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"

if ! "$DOCKER_BIN" compose -f "$COMPOSE_FILE" ps -a --services 2>/dev/null | grep -q '^kometa$'; then
    "$DOCKER_BIN" compose -f "$COMPOSE_FILE" up -d --no-deps kometa
else
    "$DOCKER_BIN" start kometa 2>/dev/null || "$DOCKER_BIN" compose -f "$COMPOSE_FILE" up -d --no-deps kometa
fi
