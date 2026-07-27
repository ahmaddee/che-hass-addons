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

# Relocate the baked tmux.conf from /root/ (where the Dockerfile COPY dropped it,
# because we built with WORKDIR=/config and no chowning) to $HOME (/data/home)
# where tmux actually reads it — since we export HOME=/data/home. Without this
# copy, tmux runs on stock defaults (mouse off, history 2000) even though our
# rootfs has the "right" .tmux.conf. NC caught this the hard way.
#
# Guard [ ! -f ] means user edits to /data/home/.tmux.conf are preserved across
# addon restarts. First-boot only.
if [ -f /root/.tmux.conf ] && [ ! -f "$DATA_HOME/.tmux.conf" ]; then
    cp /root/.tmux.conf "$DATA_HOME/.tmux.conf"
    bashio::log.info "[10-env] Seeded $DATA_HOME/.tmux.conf from image bake"

# ...but "first-boot only" also means a shipped FIX never reaches anyone who
# already has the file. 0.1.4 fixed scrolling in the baked config and it sat in
# /root/ unread for eight releases, because /data/home/.tmux.conf already
# existed. Every apparent fix after that was a live `tmux set`, undone by the
# next restart — which is exactly why the bug looked intermittent.
#
# So: repair the one known-broken shape. A config with `mouse on` and no
# alternate-screen override cannot scroll in a browser (tmux captures the wheel
# for copy-mode; xterm.js never sees it). That combination is never a
# deliberate user choice here, so replacing it is safe. Anything else — genuine
# customisation — is left completely alone.
elif [ -f /root/.tmux.conf ] && [ -f "$DATA_HOME/.tmux.conf" ] \
     && grep -q '^set -g mouse on' "$DATA_HOME/.tmux.conf" \
     && ! grep -q 'smcup@' "$DATA_HOME/.tmux.conf"; then
    cp -a "$DATA_HOME/.tmux.conf" "$DATA_HOME/.tmux.conf.bak-premouse"
    cp /root/.tmux.conf "$DATA_HOME/.tmux.conf"
    bashio::log.warning "[10-env] Repaired pre-0.1.4 .tmux.conf (scrolling was broken; backup at .tmux.conf.bak-premouse)"
fi
