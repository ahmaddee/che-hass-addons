# CHE Claude in HomE Assistant

A web-based terminal that runs Anthropic's Claude Code CLI inside Home Assistant. Designed to feel native, resilient, and out of your way.

## First-time setup

1. **Install** the add-on from the CHE Add-ons repository.
2. **Start** it. Wait ~20 seconds for the first boot (installing the Claude CLI, initializing `/data`).
3. **Open the Web UI.** You'll see a terminal and Claude's OAuth prompt on first launch. Log in with your Anthropic account.
4. That's it. Your auth persists across restarts.

## Configuration

### `auto_launch_claude` *(bool, default: true)*
When true, opening the terminal drops you straight into `claude`. When false, you land on a session picker menu.

### `survive_restart` *(bool, default: true)*
When true, Claude runs inside a persistent tmux session. Close the browser tab, come back later — same conversation, still there.

⚠️ **Setting this to `false` is not recommended.** ttyd sends SIGHUP to your shell on every WebSocket close — that includes tab-switches inside the HA sidebar, browser refreshes, and idle-disconnects. Without tmux holding the session, this means your Claude conversation dies **every time you tab away**. The tmux wrapper is what makes this add-on feel resilient; disabling it exposes an upstream ttyd behaviour that has no good workaround. Leave this at `true` unless you have a very specific reason to want fresh shells.

### `sidebar_title` *(string, default: "CHE Claude")*
The label shown in HA's sidebar for this add-on. Requires an add-on restart to take effect.

### `working_directory` *(string, default: "/config")*
Where shells start when you open the terminal — and, importantly, where Claude Code keys per-project memory. `/config` (default) means Claude scopes memory to your HA config directory, which is usually what you want. Change this only if you have a specific reason; the path must exist inside the container or the add-on falls back to `$HOME` (`/data/home`).

### `dangerously_skip_permissions` *(bool, default: false)*
Passes `--dangerously-skip-permissions` to Claude on launch. Skips all permission prompts — Claude will read, write, and execute without asking. **Only enable if you fully trust what you're about to do.**

### `claude_source` *(baked | latest_npm | pinned_version, default: baked)*
How to source the Claude Code CLI:
- **baked** — Use whatever version was baked into this add-on image. Safest. Updates ship with add-on releases.
- **latest_npm** — On every start, install the latest `@anthropic-ai/claude-code` from npm. Bleeding edge, but risk of a broken update landing between add-on updates.
- **pinned_version** — Install an exact version (see `claude_pinned_version` below). Great safety net if `latest_npm` breaks and you need to roll back.

### `claude_pinned_version` *(string, default: "")*
Only used when `claude_source: pinned_version`. Enter an exact npm version string, e.g. `2.1.198`.

### Feature toggles

- `enable_wa_watcher` *(bool, default: false)* — Enables the WhatsApp bridge daemon (see WhatsApp section below)
- `enable_playwright` *(bool, default: false)* — Installs Chromium + Playwright MCP for browser automation. Heavy install, only turn on if you need it.
- `enable_image_upload` *(bool, default: true)* — Enables the image-paste service that lets you drop screenshots into the terminal
- `enable_mcp_defaults` *(bool, default: true)* — Seeds `~/.claude/settings.json` with sensible default MCP servers (HA + time)

### Persistent packages

These lists auto-install packages every time the add-on starts, into `/data/packages` so they survive image rebuilds:

- `persistent_apk_packages` — Alpine system packages, e.g. `["vim", "htop", "tree"]`
- `persistent_pip_packages` — Python packages, e.g. `["requests", "pandas"]`
- `persistent_npm_packages` — Global npm packages, e.g. `["playwright"]`

You can also install ad-hoc from inside the terminal using `persist-install <pkg>` or `persist-install --python <pkg>`.

## Baked-in helpers

Every terminal shell has these on PATH:

### `hac`

A wrapper around the HA REST API. Reads the token from `/config/secrets.yaml::claude_ha_token`.

```
hac /api/states                       # list all entity states
hac /api/states/sensor.temperature    # single entity
hac -X POST -d '{...}' /api/services/light/turn_on
```

### `persist-install`

Install packages into `/data/packages` so they survive image rebuilds.

```
persist-install git vim htop          # apk packages
persist-install --python requests     # Python packages
persist-install --list                # what's installed
```

### `claude`

The Claude Code CLI. Wrapped in tmux by default (when `survive_restart: true`).

### `claude-session-picker`

Interactive menu for managing multiple Claude conversations. Available even when `auto_launch_claude: true` — Claude falls back to it on exit.

## Storage layout

Everything the add-on writes persistently lives in `/data`:

```
/data/
├── home/                 # HOME for shells and Claude
│   ├── .claude/          # Claude Code settings, sessions, skills, agents
│   └── .local/bin/       # user-installed binaries
├── .config/
│   ├── claude/           # ANTHROPIC_CONFIG_DIR — auth tokens live here
│   └── gh/               # GitHub CLI config
├── .cache/               # XDG_CACHE_HOME
├── .local/state/         # XDG_STATE_HOME
├── packages/
│   ├── bin/              # persist-install apk binaries
│   ├── lib/              # persist-install libs
│   └── python/venv/      # persist-install Python venv
└── npm/                  # optional user-managed npm root (for latest_npm mode)
```

## Troubleshooting

**Terminal shows "session closed" after a browser refresh**
That should not happen with `survive_restart: true`. Check that tmux is running: from a shell in the add-on, `tmux ls`. If the `claude` session is missing, restart the add-on.

**Scrollback doesn't work**
Terminal scrollback is enabled by default (100k lines). If you're stuck on old behavior where mouse wheel scrolls the parent iframe instead of the terminal, hard-refresh your browser once — the ttyd client is cached.

**Claude can't authenticate**
Anthropic OAuth needs to open a browser tab. Copy the URL Claude prints, paste into any browser (doesn't have to be the same device), complete auth. The redirect URL Claude wants you to paste back may look wrong — paste it verbatim.

**"Cannot pull image" / build failing on install**
Most likely the base image or Claude CLI download is temporarily unavailable. Check the add-on logs for the exact error, and try again in a few minutes.

## Uninstalling

Removing the add-on **does not** delete `/data`. If you reinstall later, your auth, settings, and packages come back. To fully wipe, you'll need to remove the add-on's data directory from the Supervisor.

## Support

Open an issue at [ahmaddee/che-hass-addons](https://github.com/ahmaddee/che-hass-addons/issues).
