#!/bin/bash

COMPOSE_DIR="/home/tim/twenty"
ENV_FILE="$COMPOSE_DIR/.env"
LOG_FILE="$COMPOSE_DIR/update.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Compare two semver strings: returns 0 if $1 >= $2
semver_gte() {
  printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# Get latest release tag from GitHub (including pre-releases, sorted by semver)
LATEST=$(curl -s https://api.github.com/repos/twentyhq/twenty/releases | grep '"tag_name"' | cut -d'"' -f4 | sort -V | tail -1)

if [ -z "$LATEST" ]; then
  log "ERROR: Could not fetch latest release tag"
  exit 1
fi

# Get current tag from .env
CURRENT=$(grep '^TAG=' "$ENV_FILE" | cut -d'=' -f2)

if [ "$CURRENT" = "$LATEST" ]; then
  log "Already on latest version ($CURRENT), no update needed"
  exit 0
fi

# Prevent downgrades
if semver_gte "$CURRENT" "$LATEST"; then
  log "Current version ($CURRENT) is newer than or equal to latest release ($LATEST), skipping"
  exit 0
fi

log "Updating from $CURRENT to $LATEST"

# Update TAG in .env
sed -i "s/^TAG=.*/TAG=$LATEST/" "$ENV_FILE"

# Pull new images — revert .env on failure
cd "$COMPOSE_DIR"
if ! docker compose pull >> "$LOG_FILE" 2>&1; then
  log "ERROR: docker compose pull failed, reverting to $CURRENT"
  sed -i "s/^TAG=.*/TAG=$CURRENT/" "$ENV_FILE"
  exit 1
fi

# Restart stack
if ! docker compose up -d >> "$LOG_FILE" 2>&1; then
  log "ERROR: docker compose up failed, reverting to $CURRENT"
  sed -i "s/^TAG=.*/TAG=$CURRENT/" "$ENV_FILE"
  docker compose up -d >> "$LOG_FILE" 2>&1
  exit 1
fi

log "Update complete: now running $LATEST"
