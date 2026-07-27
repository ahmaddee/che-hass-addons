# Changelog

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
