# Changelog

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
