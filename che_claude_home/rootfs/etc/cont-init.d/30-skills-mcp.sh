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
if bashio::config.true 'enable_mcp_defaults'; then
    SETTINGS="$CLAUDE_HOME/settings.json"

    # Install into /data/packages so it survives image rebuilds. Guarded so it
    # only runs once, and non-fatal so a boot without network cannot abort
    # container start — it simply retries on the next one.
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

    mkdir -p "$CLAUDE_HOME"

    if [ ! -f "$SETTINGS" ]; then
        bashio::log.info "[30-skills] Writing default MCP config to $SETTINGS (tz=${TIME_ZONE})"
        jq -n --arg bin "$TIME_BIN" --arg tz "$TIME_ZONE" '{
          mcpServers: {
            time: {
              type: "stdio",
              command: $bin,
              args: ["--local-timezone=\($tz)"]
            }
          }
        }' > "$SETTINGS"

    elif jq -e '.mcpServers.time.command == "uvx"' "$SETTINGS" >/dev/null 2>&1; then
        # Repair add-ons seeded by <= 0.1.2. Without this, existing installs stay
        # broken forever, because the branch below deliberately never touches an
        # existing settings.json. Only the one known-bad key is rewritten;
        # everything else the user has set is preserved.
        bashio::log.warning "[30-skills] Repairing unusable uvx-based time server in $SETTINGS"
        cp -a "$SETTINGS" "${SETTINGS}.bak-uvx"
        TMP_SETTINGS="$(mktemp)"
        if jq --arg bin "$TIME_BIN" --arg tz "$TIME_ZONE" '.mcpServers.time = {
              type: "stdio",
              command: $bin,
              args: ["--local-timezone=\($tz)"]
            }' "$SETTINGS" > "$TMP_SETTINGS"; then
            mv "$TMP_SETTINGS" "$SETTINGS"
            bashio::log.info "[30-skills] Repaired (backup at ${SETTINGS}.bak-uvx)"
        else
            rm -f "$TMP_SETTINGS"
            bashio::log.warning "[30-skills] Repair failed — leaving $SETTINGS untouched"
        fi

    else
        bashio::log.info "[30-skills] $SETTINGS exists — leaving user config untouched"
    fi
else
    bashio::log.info "[30-skills] enable_mcp_defaults=false — skipping MCP seed"
fi
