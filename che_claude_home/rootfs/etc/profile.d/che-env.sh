# Loaded for every bash session — persistent env for shells spawned inside ttyd.
# Kept in lockstep with /etc/cont-init.d/10-env.sh (which sets the same for s6 services).

export HOME="/data/home"
export XDG_CONFIG_HOME="/data/.config"
export XDG_CACHE_HOME="/data/.cache"
export XDG_STATE_HOME="/data/.local/state"
export XDG_DATA_HOME="/data/.local/share"

# Claude Code specifics
export ANTHROPIC_CONFIG_DIR="/data/.config/claude"
export ANTHROPIC_HOME="/data"
export DISABLE_AUTOUPDATER=1
export IS_SANDBOX=1

# GitHub CLI persistent config
export GH_CONFIG_DIR="/data/.config/gh"

# Persistent package paths (HIGHEST PRIORITY)
export PATH="/data/packages/bin:/data/packages/python/venv/bin:/data/home/.local/bin:/data/npm/bin:$PATH"
export LD_LIBRARY_PATH="/data/packages/lib:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="/data/packages/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

if [ -d "/data/packages/python/venv" ]; then
    export VIRTUAL_ENV="/data/packages/python/venv"
fi
