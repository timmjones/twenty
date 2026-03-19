#!/bin/bash

COMPOSE_DIR="/home/tim/twenty"
ENV_FILE="$COMPOSE_DIR/.env"
LOG_FILE="$COMPOSE_DIR/update.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Get latest release tag from GitHub
LATEST=$(curl -s https://api.github.com/repos/twentyhq/twenty/releases/latest | grep '"tag_name"' | head -1 | cut -d'"' -f4)

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

log "Updating from $CURRENT to $LATEST"

# Update TAG in .env
sed -i "s/^TAG=.*/TAG=$LATEST/" "$ENV_FILE"

# Pull new images and restart
cd "$COMPOSE_DIR"
docker compose pull >> "$LOG_FILE" 2>&1
docker compose up -d >> "$LOG_FILE" 2>&1

log "Update complete: now running $LATEST"
