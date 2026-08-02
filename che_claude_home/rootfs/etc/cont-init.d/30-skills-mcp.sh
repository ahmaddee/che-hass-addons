#!/usr/bin/with-contenv bashio
# ============================================================================
# 30-skills-mcp.sh — seed skills + optional MCP defaults on first boot
# ============================================================================
set -euo pipefail

CLAUDE_HOME="/data/home/.claude"
SEED_SRC="/opt/.claude"

# The time MCP server runs from the persistent venv. It is deliberately NOT
# `uvx` — `uv`/`uvx` is not installed in this image, so the definition seeded by
# <= 0.1.2 pointed at a binary that never existed. That failure is silent: the
# config is written, the log looks healthy, and the server simply never starts.
TIME_BIN="/data/packages/python/venv/bin/mcp-server-time"

# --- Seed skills / commands / agents on first boot only ---
if [ -d "$SEED_SRC" ]; then
    if [ ! -d "$CLAUDE_HOME" ]; then
        bashio::log.info "[30-skills] Seeding $CLAUDE_HOME from $SEED_SRC"
        cp -r "$SEED_SRC" "$CLAUDE_HOME"
    else
        # Only add new files, never overwrite user customizations
        bashio::log.info "[30-skills] $CLAUDE_HOME exists — top-up mode (no overwrite)"
        cp -rn "$SEED_SRC"/* "$CLAUDE_HOME"/ 2>/dev/null || true
    fi
fi

# --- Optionally seed default MCP config ---
#
# ⚠️ TARGET FILE: ~/.claude.json — NOT ~/.claude/settings.json.
#
# Claude Code reads MCP server definitions ONLY from `~/.claude.json` (user and
# local scope) and `.mcp.json` (project scope). `mcpServers` is not a documented
# key in settings.json and is never read from there.
#
# Releases up to 0.1.12 wrote the seed into `~/.claude/settings.json`, so
# `enable_mcp_defaults` silently did nothing on every install that has ever
# existed: the file was written, the log said "Writing default MCP config", and
# no server was ever registered. Same failure shape as the uvx bug below and as
# the tmux.conf written to /root while HOME was /data/home — something written
# correctly, and the thing meant to consume it looking somewhere else.
#
# `.claude.json` also holds the OAuth session, per-project trust state and
# caches, so it is ALWAYS merged with jq and written atomically. Never truncate it.
if bashio::config.true 'enable_mcp_defaults'; then
    CLAUDE_JSON="/data/home/.claude.json"
    LEGACY_SETTINGS="$CLAUDE_HOME/settings.json"

    # Install into /data/packages so it survives image rebuilds. Non-fatal so a
    # boot without network cannot abort container start — it retries next boot.
    if [ ! -x "$TIME_BIN" ]; then
        bashio::log.info "[30-skills] Installing mcp-server-time into /data/packages"
        if persist-install --python mcp-server-time >/dev/null 2>&1; then
            bashio::log.info "[30-skills] mcp-server-time ready"
        else
            bashio::log.warning "[30-skills] mcp-server-time install failed (offline?) — will retry next start"
        fi
    fi

    # Supervisor exports TZ from Home Assistant's configured timezone.
    TIME_ZONE="${TZ:-UTC}"

    mkdir -p "$CLAUDE_HOME" /data/home

    # Ensure the file exists and is valid JSON before jq touches it. A truncated
    # or absent file must not make the whole boot fail.
    if [ ! -f "$CLAUDE_JSON" ]; then
        echo '{}' > "$CLAUDE_JSON"
        bashio::log.info "[30-skills] Created $CLAUDE_JSON"
    elif ! jq -e . "$CLAUDE_JSON" >/dev/null 2>&1; then
        bashio::log.warning "[30-skills] $CLAUDE_JSON is not valid JSON — leaving it alone"
        CLAUDE_JSON=""
    fi

    if [ -n "$CLAUDE_JSON" ]; then
        # ── Home Assistant, via the Supervisor proxy ────────────────────────
        # http://supervisor/core/api/mcp is HA's STATELESS Streamable HTTP
        # endpoint, reachable with the add-on's own SUPERVISOR_TOKEN. No
        # long-lived token to mint, no IP to configure — `supervisor` is a fixed
        # internal hostname, so this is identical on every install.
        #
        # Stateless matters: the legacy /mcp_server/sse endpoint keeps an
        # in-memory session, so restarting HA Core 404s every subsequent call
        # until the client reconnects. The stateless route has no session to
        # invalidate. (Confirmed against HA 2026.7.4; MCP spec 2026-07-28 removes
        # protocol-level sessions entirely and deprecates HTTP+SSE.)
        #
        # timeout: Claude Code aborts a tool call idle for 5 minutes on http
        # transports. HA scripts that hold an internal delay trip that and report
        # a false failure. A per-server timeout raises it. Needs Claude Code
        # >= 2.1.203.
        #
        # ⚠️ THE CREDENTIAL IS A REFERENCE, NOT A VALUE.
        #
        # Supervisor mints a brand-new SUPERVISOR_TOKEN on *every* add-on start
        # (`secrets.token_hex(56)` in supervisor/apps/app.py), so a token written
        # literally into this file would be stale the moment the container next
        # restarts — presenting as "HA control mysteriously dead after a restart",
        # indistinguishable from the SSE session bug but with a different cause.
        #
        # Writing the literal string `${SUPERVISOR_TOKEN}` sidesteps that
        # entirely: Claude Code expands it from the process environment at load
        # time, so it always resolves to the current token and this file never
        # needs rewriting. Documented for "a local- or user-scoped server entry in
        # ~/.claude.json", with `headers` explicitly among the supported fields.
        #
        # Consequence worth keeping: the token never lands on disk, never in a
        # backup, never in a diff or a screenshot. It exists only in the running
        # container's environment.
        #
        # If SUPERVISOR_TOKEN is somehow unset the config still loads — Claude
        # Code reports a missing-variable warning in `claude mcp list` and passes
        # the literal text through, which 401s cleanly rather than crashing.
        HA_URL="http://supervisor/core/api/mcp"

        # Only manage this entry while it still points at our URL. If the user has
        # repointed it at their own HA instance with their own token, leave it be.
        EXISTING_URL="$(jq -r '.mcpServers.homeassistant.url // ""' "$CLAUDE_JSON")"
        if [ -n "$EXISTING_URL" ] && [ "$EXISTING_URL" != "$HA_URL" ]; then
            bashio::log.info "[30-skills] homeassistant MCP is user-customised (${EXISTING_URL}) — not touching it"
        else
            # Surgical field assignment, not wholesale replacement. `//=` only
            # initialises when missing, so anything else the user has added — an
            # extra header, a longer timeout — survives. We own exactly the
            # credential path and the URL; they own the rest.
            #
            # Overwriting Authorization here is a repair, not a stomp: this URL is
            # the Supervisor proxy, which accepts SUPERVISOR_TOKEN and 401s
            # anything else, so it is the only credential that can work.
            TMP="$(mktemp -p "$(dirname "$CLAUDE_JSON")")"
            if jq --arg url "$HA_URL" '
                  .mcpServers //= {} |
                  .mcpServers.homeassistant //= {} |
                  .mcpServers.homeassistant.type = "http" |
                  .mcpServers.homeassistant.url = $url |
                  .mcpServers.homeassistant.headers //= {} |
                  .mcpServers.homeassistant.headers.Authorization = "Bearer ${SUPERVISOR_TOKEN}" |
                  .mcpServers.homeassistant.timeout //= 900000
                 ' "$CLAUDE_JSON" > "$TMP" && jq -e . "$TMP" >/dev/null 2>&1; then
                # Same-filesystem rename → atomic. A crash mid-write leaves the
                # original intact rather than a truncated file that Claude Code
                # also can't read. mktemp -p keeps it off /tmp (tmpfs), which
                # would silently degrade mv to copy+unlink and lose atomicity.
                mv -f "$TMP" "$CLAUDE_JSON"
                bashio::log.info "[30-skills] Home Assistant MCP enabled (Supervisor proxy)."
                bashio::log.info "[30-skills]   → Claude can act on entities you expose at"
                bashio::log.info "[30-skills]     Settings → Voice assistants → Expose. Default: none."
                bashio::log.info "[30-skills]   → Turn off with enable_mcp_defaults: false"
            else
                rm -f "$TMP"
                bashio::log.warning "[30-skills] Failed to write Home Assistant MCP entry — leaving config untouched"
            fi
        fi

        # ── time ───────────────────────────────────────────────────────────
        # Seeded only when absent, or when it is the known-broken uvx definition
        # from <= 0.1.2 (uv/uvx is not in this image, so that server never
        # started — silently, because the config looked fine).
        NEEDS_TIME=0
        jq -e '.mcpServers.time == null or .mcpServers.time.command == "uvx"' \
            "$CLAUDE_JSON" >/dev/null 2>&1 && NEEDS_TIME=1

        if [ "$NEEDS_TIME" = "1" ]; then
            TMP="$(mktemp -p "$(dirname "$CLAUDE_JSON")")"
            if jq --arg bin "$TIME_BIN" --arg tz "$TIME_ZONE" '
                  .mcpServers //= {} |
                  .mcpServers.time = {
                    type: "stdio",
                    command: $bin,
                    args: ["--local-timezone=\($tz)"]
                  }' "$CLAUDE_JSON" > "$TMP" && jq -e . "$TMP" >/dev/null 2>&1; then
                mv -f "$TMP" "$CLAUDE_JSON"
                bashio::log.info "[30-skills] Seeded time MCP server (tz=${TIME_ZONE})"
            else
                rm -f "$TMP"
                bashio::log.warning "[30-skills] Failed to write time MCP entry — leaving config untouched"
            fi
        fi

        # ── Retire the mis-targeted legacy block ────────────────────────────
        # Anything <= 0.1.12 wrote landed in settings.json where it was never
        # read. Strip just that key so the file stops implying MCP is configured
        # there; every other setting the user has is preserved.
        if [ -f "$LEGACY_SETTINGS" ] && jq -e '.mcpServers' "$LEGACY_SETTINGS" >/dev/null 2>&1; then
            cp -a "$LEGACY_SETTINGS" "${LEGACY_SETTINGS}.bak-mcpmove"
            TMP="$(mktemp -p "$(dirname "$LEGACY_SETTINGS")")"
            if jq 'del(.mcpServers)' "$LEGACY_SETTINGS" > "$TMP" && jq -e . "$TMP" >/dev/null 2>&1; then
                mv -f "$TMP" "$LEGACY_SETTINGS"
                bashio::log.info "[30-skills] Removed inert mcpServers from settings.json (backup: ${LEGACY_SETTINGS}.bak-mcpmove)"
            fi
            rm -f "$TMP"
        fi
    fi
else
    bashio::log.info "[30-skills] enable_mcp_defaults=false — skipping MCP seed"
fi
