#!/usr/bin/with-contenv bashio
# ============================================================================
# 40-persist-packages.sh — auto-install packages from config into /data/packages
# ============================================================================
set -euo pipefail

PERSIST_INSTALL="/usr/local/bin/persist-install"

if [ ! -x "$PERSIST_INSTALL" ]; then
    bashio::log.warning "[40-persist] persist-install not on PATH — skipping auto-install"
    exit 0
fi

# Bashio can return newline-separated OR JSON arrays; handle both.
normalize_list() {
    local raw="$1"
    [ -z "$raw" ] || [ "$raw" = "[]" ] && return 0
    if printf '%s' "$raw" | jq -e 'type == "array"' >/dev/null 2>&1; then
        printf '%s' "$raw" | jq -r '.[]'
    else
        printf '%s\n' "$raw"
    fi
}

APK=$(normalize_list "$(bashio::config 'persistent_apk_packages' '')")
PIP=$(normalize_list "$(bashio::config 'persistent_pip_packages' '')")
NPM=$(normalize_list "$(bashio::config 'persistent_npm_packages' '')")

if [ -n "$APK" ]; then
    bashio::log.info "[40-persist] Auto-installing apk packages..."
    while IFS= read -r pkg; do
        [ -n "$pkg" ] && "$PERSIST_INSTALL" "$pkg" \
            || bashio::log.warning "[40-persist] failed apk: $pkg"
    done <<< "$APK"
fi

if [ -n "$PIP" ]; then
    bashio::log.info "[40-persist] Auto-installing pip packages..."
    pip_list=()
    while IFS= read -r pkg; do
        [ -n "$pkg" ] && pip_list+=("$pkg")
    done <<< "$PIP"
    if [ "${#pip_list[@]}" -gt 0 ]; then
        "$PERSIST_INSTALL" --python "${pip_list[@]}" \
            || bashio::log.warning "[40-persist] pip install failed"
    fi
fi

if [ -n "$NPM" ]; then
    bashio::log.info "[40-persist] Auto-installing npm packages into /data/npm..."
    mkdir -p /data/npm
    while IFS= read -r pkg; do
        if [ -n "$pkg" ]; then
            NPM_CONFIG_PREFIX="/data/npm" npm install -g "$pkg" \
                || bashio::log.warning "[40-persist] failed npm: $pkg"
        fi
    done <<< "$NPM"
fi
