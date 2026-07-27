#!/usr/bin/with-contenv bashio
# ============================================================================
# 20-claude-source.sh — resolve claude_source option
#
# Modes:
#   baked          → use image-baked binary (default; symlink to /data/home
#                    for HOME=/data/home lookup)
#   latest_npm     → install @anthropic-ai/claude-code@latest on every start
#   pinned_version → install a user-specified exact version
# ============================================================================
set -euo pipefail

CLAUDE_SOURCE=$(bashio::config 'claude_source' 'baked')
CLAUDE_PIN=$(bashio::config 'claude_pinned_version' '')
NPM_ROOT="/data/npm"
CLAUDE_LINK="/usr/local/bin/claude"
DATA_HOME_BIN="/data/home/.local/bin"

mkdir -p "$DATA_HOME_BIN"

# Always ensure the image-baked native binary is symlinked into /data/home,
# so Claude's HOME=/data/home self-check works even if we override later.
if [ -f /root/.local/bin/claude ] && [ ! -L "$DATA_HOME_BIN/claude" ]; then
    ln -sf /root/.local/bin/claude "$DATA_HOME_BIN/claude"
    bashio::log.info "[20-claude] Native binary linked into /data/home/.local/bin"
fi

case "$CLAUDE_SOURCE" in
    baked)
        bashio::log.info "[20-claude] Source: baked (using image-provided version)"
        # /usr/local/bin/claude was already set by Dockerfile — nothing to do
        ;;

    latest_npm)
        bashio::log.info "[20-claude] Source: latest_npm — installing @anthropic-ai/claude-code@latest into $NPM_ROOT"
        mkdir -p "$NPM_ROOT"
        if NPM_CONFIG_PREFIX="$NPM_ROOT" npm install -g @anthropic-ai/claude-code@latest --prefer-online; then
            ln -sf "$NPM_ROOT/bin/claude" "$CLAUDE_LINK"
            bashio::log.info "[20-claude] latest_npm active: $CLAUDE_LINK -> $NPM_ROOT/bin/claude"
            # Disable auto-updates — we're controlling versions
            unset DISABLE_AUTOUPDATER || true
        else
            bashio::log.warning "[20-claude] latest_npm install failed — falling back to baked binary"
        fi
        ;;

    pinned_version)
        if [ -z "$CLAUDE_PIN" ]; then
            bashio::log.warning "[20-claude] pinned_version selected but claude_pinned_version is empty — falling back to baked"
        else
            bashio::log.info "[20-claude] Source: pinned_version — installing @anthropic-ai/claude-code@$CLAUDE_PIN"
            mkdir -p "$NPM_ROOT"
            if NPM_CONFIG_PREFIX="$NPM_ROOT" npm install -g "@anthropic-ai/claude-code@$CLAUDE_PIN" --prefer-online; then
                ln -sf "$NPM_ROOT/bin/claude" "$CLAUDE_LINK"
                bashio::log.info "[20-claude] pinned_version active: $CLAUDE_PIN"
            else
                bashio::log.warning "[20-claude] Failed to install $CLAUDE_PIN — falling back to baked binary"
            fi
        fi
        ;;

    *)
        bashio::log.warning "[20-claude] Unknown claude_source '$CLAUDE_SOURCE' — using baked"
        ;;
esac

# Version smoke-test — log what we're actually running
if command -v claude >/dev/null 2>&1; then
    VER=$(timeout 15 claude --version 2>/dev/null || echo "unknown")
    bashio::log.info "[20-claude] claude --version → $VER"
fi
