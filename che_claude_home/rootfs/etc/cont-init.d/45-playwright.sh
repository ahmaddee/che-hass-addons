#!/usr/bin/with-contenv bashio
# ============================================================================
# 45-playwright.sh — make `enable_playwright` actually do something
#
# Like enable_image_upload before 0.1.6, this option shipped with no
# implementation. Toggling it changed nothing.
#
# Two dead ends worth recording, because both look like the obvious answer:
#
#   - Google Chrome (the Playwright MCP's default) has NO Linux ARM64 build.
#     On a Pi it fails with "Chromium distribution 'chrome' is not found".
#   - `npx playwright install chromium` downloads a glibc-linked build that
#     cannot execute on Alpine/musl at all.
#
# What works is Alpine's own chromium package — musl-native — with the MCP
# pointed at it via --executable-path.
#
# Cost: ~857 MiB across ~266 packages, so first boot with this enabled is slow.
# That is why it is opt-in and why the log says so out loud.
#
# ⚠️ 0.1.16 — THE SERVER ENTRY WAS BEING WRITTEN WHERE NOTHING READS IT.
#
# Until now this wrote `mcpServers.playwright` into `.claude/settings.json`.
# Claude Code does not read MCP servers from settings.json — only from
# `~/.claude.json` and `.mcp.json`. So the browser installed, the log said
# "Ready", and no browser tools ever appeared.
#
# It was worse than inert: 30-skills-mcp.sh runs FIRST (lexical order) and
# deletes `.mcpServers` from settings.json precisely because it is dead config
# — then this script wrote it straight back into the same dead file. Two
# scripts, opposite directions, on a key neither of them could make work.
#
# This is instance #8 of the house bug: written correctly, read from somewhere
# else. Same root cause as enable_mcp_defaults in 0.1.13.
# ============================================================================
set -euo pipefail

CLAUDE_HOME="/data/home/.claude"
CLAUDE_JSON="/data/home/.claude.json"
CHROMIUM_BIN="/usr/bin/chromium-browser"

if ! bashio::config.true 'enable_playwright'; then
    bashio::log.info "[45-playwright] enable_playwright=false — skipping"
    return 0 2>/dev/null || exit 0
fi

# --- Browser -----------------------------------------------------------------
if [ ! -x "$CHROMIUM_BIN" ]; then
    bashio::log.info "[45-playwright] Installing Chromium — ~857 MiB, first boot will take several minutes"
    # Fonts are not optional: without them text renders as boxes in screenshots.
    if persist-install chromium chromium-chromedriver font-noto font-noto-emoji >/dev/null 2>&1; then
        bashio::log.info "[45-playwright] Chromium installed"
    else
        bashio::log.warning "[45-playwright] Chromium install failed (offline?) — will retry next start"
    fi
else
    bashio::log.info "[45-playwright] Chromium already present"
fi

# --- MCP wiring ---------------------------------------------------------------
# Installing a browser without wiring it up would leave the option half-done in
# exactly the way this hook exists to fix.
if [ ! -x "$CHROMIUM_BIN" ]; then
    bashio::log.warning "[45-playwright] No browser — leaving MCP config alone"
    return 0 2>/dev/null || exit 0
fi

mkdir -p "$CLAUDE_HOME" /data/home /share/che-uploads/playwright

# .claude.json also holds the OAuth session and per-project trust state, so it
# is always merged with jq and written atomically — never truncated.
[ -f "$CLAUDE_JSON" ] || echo '{}' > "$CLAUDE_JSON"
if ! jq -e . "$CLAUDE_JSON" >/dev/null 2>&1; then
    bashio::log.warning "[45-playwright] $CLAUDE_JSON is not valid JSON — leaving it alone"
    return 0 2>/dev/null || exit 0
fi

# One-time cleanup: drop the entry earlier versions wrote into settings.json,
# where it never did anything. Backed up rather than silently discarded.
LEGACY_SETTINGS="${CLAUDE_HOME}/settings.json"
if [ -f "$LEGACY_SETTINGS" ] && jq -e '.mcpServers.playwright' "$LEGACY_SETTINGS" >/dev/null 2>&1; then
    cp -a "$LEGACY_SETTINGS" "${LEGACY_SETTINGS}.bak-playwrightmove"
    TMP="$(mktemp -p "$(dirname "$LEGACY_SETTINGS")")"
    if jq 'del(.mcpServers.playwright)' "$LEGACY_SETTINGS" > "$TMP" && jq -e . "$TMP" >/dev/null 2>&1; then
        mv -f "$TMP" "$LEGACY_SETTINGS"
        bashio::log.info "[45-playwright] Removed inert playwright entry from settings.json (backup: ${LEGACY_SETTINGS}.bak-playwrightmove)"
    else
        rm -f "$TMP"
    fi
fi

if jq -e '.mcpServers.playwright' "$CLAUDE_JSON" >/dev/null 2>&1; then
    bashio::log.info "[45-playwright] playwright MCP already configured — leaving user config untouched"
else
    bashio::log.info "[45-playwright] Adding playwright MCP server to ${CLAUDE_JSON}"
    # mktemp -p keeps the temp file on the same filesystem so `mv` is atomic.
    # /tmp is tmpfs, which would silently degrade it to copy+unlink.
    TMP="$(mktemp -p "$(dirname "$CLAUDE_JSON")")"
    # --no-sandbox is required running as root in a container.
    # --isolated keeps the browser profile in memory, so every session starts
    # logged out of anything. Swap for --user-data-dir if you want sessions to
    # persist; this script will not overwrite your change.
    if jq --arg bin "$CHROMIUM_BIN" '
          .mcpServers //= {} |
          .mcpServers.playwright = {
            type: "stdio",
            command: "npx",
            args: ["-y", "@playwright/mcp@latest",
                   "--browser", "chromium",
                   "--executable-path", $bin,
                   "--headless", "--no-sandbox", "--isolated",
                   "--output-dir", "/share/che-uploads/playwright"]
          }' "$CLAUDE_JSON" > "$TMP" && jq -e . "$TMP" >/dev/null 2>&1; then
        mv -f "$TMP" "$CLAUDE_JSON"
        bashio::log.info "[45-playwright] Ready — restart Claude Code to load the browser tools"
    else
        rm -f "$TMP"
        bashio::log.warning "[45-playwright] Could not update ${CLAUDE_JSON} — left untouched"
    fi
fi
