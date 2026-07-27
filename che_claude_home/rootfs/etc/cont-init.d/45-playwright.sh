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
# ============================================================================
set -euo pipefail

CLAUDE_HOME="/data/home/.claude"
SETTINGS="${CLAUDE_HOME}/settings.json"
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

mkdir -p "$CLAUDE_HOME" /share/che-uploads/playwright
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

if jq -e '.mcpServers.playwright' "$SETTINGS" >/dev/null 2>&1; then
    bashio::log.info "[45-playwright] playwright MCP already configured — leaving user config untouched"
else
    bashio::log.info "[45-playwright] Adding playwright MCP server to ${SETTINGS}"
    TMP="$(mktemp)"
    # --no-sandbox is required running as root in a container.
    # --isolated keeps the browser profile in memory between runs.
    if jq --arg bin "$CHROMIUM_BIN" '.mcpServers.playwright = {
          type: "stdio",
          command: "npx",
          args: ["-y", "@playwright/mcp@latest",
                 "--browser", "chromium",
                 "--executable-path", $bin,
                 "--headless", "--no-sandbox", "--isolated",
                 "--output-dir", "/share/che-uploads/playwright"]
        }' "$SETTINGS" > "$TMP"; then
        mv "$TMP" "$SETTINGS"
        bashio::log.info "[45-playwright] Ready — restart Claude Code to load the browser tools"
    else
        rm -f "$TMP"
        bashio::log.warning "[45-playwright] Could not update ${SETTINGS} — left untouched"
    fi
fi
