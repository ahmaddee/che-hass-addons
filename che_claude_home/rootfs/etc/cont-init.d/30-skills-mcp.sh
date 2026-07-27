#!/usr/bin/with-contenv bashio
# ============================================================================
# 30-skills-mcp.sh — seed skills + optional MCP defaults on first boot
# ============================================================================
set -euo pipefail

CLAUDE_HOME="/data/home/.claude"
SEED_SRC="/opt/.claude"

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
    if [ ! -f "$SETTINGS" ]; then
        bashio::log.info "[30-skills] Writing default MCP config to $SETTINGS"
        mkdir -p "$CLAUDE_HOME"
        cat > "$SETTINGS" <<'JSON'
{
  "mcpServers": {
    "time": {
      "command": "uvx",
      "args": ["mcp-server-time"]
    }
  }
}
JSON
    else
        bashio::log.info "[30-skills] $SETTINGS exists — leaving user config untouched"
    fi
else
    bashio::log.info "[30-skills] enable_mcp_defaults=false — skipping MCP seed"
fi
