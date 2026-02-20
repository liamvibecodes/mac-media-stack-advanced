#!/bin/bash
# Triggers a Kometa run (one-shot container).
# Called by launchd every 4 hours or manually.

DOCKER_BIN="$(command -v docker || echo /opt/homebrew/bin/docker)"

if ! "$DOCKER_BIN" compose ps -a --services 2>/dev/null | grep -q '^kometa$'; then
    "$DOCKER_BIN" compose up -d --no-deps kometa
else
    "$DOCKER_BIN" start kometa 2>/dev/null || "$DOCKER_BIN" compose up -d --no-deps kometa
fi
