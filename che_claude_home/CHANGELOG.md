# Changelog

## 0.1.3 — 2026-07-27

- **fix**: the default `time` MCP server has never been able to start. `cont-init.d/30-skills-mcp.sh` seeded it as `uvx mcp-server-time`, but `uv`/`uvx` is not installed in this image. The failure is silent — the config is written, the boot log reports success, and the server simply never comes up. It now points at `/data/packages/python/venv/bin/mcp-server-time`.
- **fix**: that binary is now actually installed. The hook runs `persist-install --python mcp-server-time` on first boot, guarded so it only runs once and non-fatal so a boot without network cannot abort container start — it retries on the next start instead.
- **fix**: existing installs are repaired, not just new ones. The seed step deliberately never overwrites an existing `settings.json`, which meant anyone already on <= 0.1.2 would have stayed broken forever. The hook now detects the specific unusable `"command": "uvx"` definition and rewrites only that key, preserving every other setting, with a `.bak-uvx` backup alongside.
- **change**: the server's timezone comes from `$TZ` (which Supervisor exports from Home Assistant's configured timezone) instead of a hardcoded value, falling back to `UTC`.

Credit: NC. Found while verifying the MCP migration end to end — `claude mcp list` reported the server healthy, which is exactly why this class of bug survives. Fourth instance of the root pattern: something is written correctly, and the thing meant to consume it isn't where the writer assumed.

## 0.1.2 — 2026-07-27

- **fix**: `.tmux.conf` was baked into `/root/` but tmux reads from `$HOME/.tmux.conf` (`/data/home/.tmux.conf`) at runtime — mouse mode and scrollback were silently running on stock defaults. `cont-init.d/10-env.sh` now copies the baked config into `$HOME` on first boot, guarded so user edits are preserved on subsequent starts.
- **fix**: shells + tmux sessions no longer inherit s6's `/run/s6/legacy-services/ttyd` as their working directory. New `working_directory` option (default `/config`) drives an explicit `cd` in `services.d/ttyd/run` and `-c` on every `tmux new-session`. This matters because Claude Code keys per-project memory by cwd — the old default silently put memory in an odd project scope.
- **new**: `working_directory` option added to config.yaml schema.
- **new**: `cont-init.d/50-claude-auth-path-shim.sh` — cosmetic symlink `/data/.config/claude → $HOME/.claude` so anything reading `ANTHROPIC_CONFIG_DIR` sees the same auth files Claude Code writes today. Idempotent, no-op if the shim path already contains real files.
- **docs**: `survive_restart: false` now carries a warning — ttyd's SIGHUP-on-close means disabling tmux exposes an upstream behaviour that kills your shell on every tab switch.

Credit: NC (parallel-test Claude in the freshly-installed addon) surfaced all three fixes during the first-boot handshake — the root pattern was `image bakes to /root/, runtime env points at /data/home/`.

## 0.1.1 — 2026-07-27

- **fix**: drop host port map on 7681 so the add-on can run in parallel with Claude Terminal Pro (also on 7681). Ingress still works out of the box; users wanting direct LAN access can set a host port via HA's Network config.
- **cleanup**: remove `webui:` field (ingress is the primary access path).

## 0.1.0 — 2026-07-27

Initial release. Development scaffold.

- Ported architecture from ESJavadex/claude-code-ha (Claude Terminal Pro) with resilience wins baked into the image
- ttyd scrollback (100k lines) and tmux mouse mode on by default
- First-class helpers: `hac`, `persist-install`, `claude-tmux`, `claude-session-picker`
- `/data`-based XDG env for HOME, XDG_*, ANTHROPIC_CONFIG_DIR
- Configurable Claude Code source: `baked` / `latest_npm` / `pinned_version`
- Configurable sidebar title
- Feature toggles for WA watcher, Playwright, image upload, MCP defaults
