#!/usr/bin/with-contenv bashio
# ============================================================================
# 50-claude-auth-path-shim.sh
#
# Claude Code 2.1.220 doesn't honour ANTHROPIC_CONFIG_DIR — it writes credentials
# to $HOME/.claude/ regardless. That works fine today (auth persists via /data),
# so this hook is cosmetic: it makes the two paths *agree* by symlinking
# /data/.config/claude → $HOME/.claude, so anything that DOES read
# ANTHROPIC_CONFIG_DIR sees the same auth files a future Claude Code version
# might.
#
# Safety: bail loudly if /data/.config/claude has real files. We only ever
# rmdir an empty directory or reuse an existing symlink. Never rm -rf.
# ============================================================================
set -euo pipefail

TARGET="/data/home/.claude"
SHIM="/data/.config/claude"

mkdir -p "$TARGET"

if [ -L "$SHIM" ]; then
    # Already a symlink — idempotent, skip.
    LINK_DEST="$(readlink -f "$SHIM" 2>/dev/null || echo "")"
    if [ "$LINK_DEST" = "$(readlink -f "$TARGET" 2>/dev/null)" ]; then
        bashio::log.info "[50-shim] $SHIM already symlinks to $TARGET — no-op"
        exit 0
    else
        bashio::log.warning "[50-shim] $SHIM is a symlink pointing elsewhere ($LINK_DEST) — leaving it alone"
        exit 0
    fi
fi

if [ -d "$SHIM" ]; then
    # Real directory. Only remove if empty.
    if [ -z "$(ls -A "$SHIM" 2>/dev/null)" ]; then
        rmdir "$SHIM"
        ln -s "$TARGET" "$SHIM"
        bashio::log.info "[50-shim] $SHIM → $TARGET (was empty dir)"
    else
        bashio::log.warning "[50-shim] $SHIM contains files — refusing to touch (Claude Code writes to \$HOME/.claude directly, so this is not blocking)"
    fi
elif [ -e "$SHIM" ]; then
    bashio::log.warning "[50-shim] $SHIM exists as a non-dir non-link — leaving it alone"
else
    # Nothing there — link fresh.
    ln -s "$TARGET" "$SHIM"
    bashio::log.info "[50-shim] $SHIM → $TARGET (fresh link)"
fi
