#!/usr/bin/with-contenv bashio
# ============================================================================
# 10-env.sh — create /data XDG dirs, seed profile.d, set container env
#
# Runs once at container start, before any s6 services. Idempotent.
# ============================================================================
set -euo pipefail

bashio::log.info "[10-env] Initializing /data storage layout..."

DATA_HOME="/data/home"
CONFIG_DIR="/data/.config"
CACHE_DIR="/data/.cache"
STATE_DIR="/data/.local/state"
CLAUDE_CFG="/data/.config/claude"
GH_CFG="/data/.config/gh"
PERSIST_ROOT="/data/packages"

mkdir -p \
    "$DATA_HOME" \
    "$CLAUDE_CFG" \
    "$GH_CFG" \
    "$CACHE_DIR" \
    "$STATE_DIR" \
    "/data/.local/share" \
    "$PERSIST_ROOT/bin" \
    "$PERSIST_ROOT/lib" \
    "$PERSIST_ROOT/python" \
    "/data/npm" \
    "/data/images"

chmod 755 "$DATA_HOME" "$CONFIG_DIR" "$CACHE_DIR" "$STATE_DIR" "$CLAUDE_CFG" "$GH_CFG" \
          "$PERSIST_ROOT" "$PERSIST_ROOT/bin" "$PERSIST_ROOT/lib" "$PERSIST_ROOT/python"

bashio::log.info "[10-env] /data layout ready"

# Migrate legacy auth locations if present (from prior Claude Terminal Pro installs)
for legacy in /root/.config/anthropic /root/.anthropic /config/claude-config; do
    if [ -d "$legacy" ] && [ -n "$(ls -A "$legacy" 2>/dev/null)" ] && [ ! -e "$legacy.migrated" ]; then
        bashio::log.info "[10-env] Migrating auth from $legacy → $CLAUDE_CFG"
        cp -r "$legacy"/* "$CLAUDE_CFG/" 2>/dev/null || true
        find "$CLAUDE_CFG" -type f -exec chmod 600 {} \; 2>/dev/null || true
        touch "$legacy.migrated"
    fi
done
