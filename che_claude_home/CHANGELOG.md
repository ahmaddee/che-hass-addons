# Changelog

## 0.1.7 — 2026-07-27

- **fix**: the **Add-on page** button 404'd. Home Assistant 2026.x renamed add-ons to *apps* and moved the panel from `/hassio/addon/<slug>/info` to `/config/app/<slug>/info`. The route is now chosen from HA's core version at boot, so installs on earlier releases still get a working link.
- **fix**: that button also built a *relative* URL, which resolves against `/api/hassio_ingress/<token>/` and 404s regardless of the route. It now takes `window.top.location.origin` explicitly.
- **fix**: it claimed to open a new tab (↗) and navigated in place, replacing the terminal. Now genuinely `window.open(..., '_blank')`.
- **fix**: `enable_playwright` did nothing — the third option to ship in the schema with no implementation behind it. New `cont-init.d/45-playwright.sh` installs Alpine's musl-native Chromium and wires the Playwright MCP to it. Google Chrome has no Linux ARM64 build at all, and Playwright's bundled Chromium is glibc-linked and won't run on Alpine — `--executable-path` against the apk build is the only route that works on a Pi.
- **note**: enabling it costs ~857 MiB and a slow first boot. Opt-in, and the log says so.

## 0.1.6 — 2026-07-27

- **fix**: `enable_image_upload` did nothing. It has been present in `config.yaml` and in the schema with **no implementation anywhere in the repo** — toggling it changed nothing, silently, with no error. New `cont-init.d/35-image-upload.sh` installs the trzsz receiver when the option is on. ttyd 1.7.7 already ships the entire client half (`TrzszAddon`, `TrzszUploadFiles`, and `trzszDragInitTimeout` for drag-and-drop); only the binary on this side was missing. No sidecar, no extra port, no HTTP endpoint.
- **new**: `/share/che-uploads` is created with a README covering the ways files can arrive — HA Media browser, Samba, File Editor, or a trzsz popup. No watcher and no daemon: the user is the trigger.
- **removed**: the in-page Restart button shipped in 0.1.5. It posted to `/api/hassio/addons/self/restart` on the browser's HA session and returns **401** — HA's API authenticates by `Authorization: Bearer`, not by cookie, and the browser cannot reach `http://supervisor` at all. Replaced with **Add-on page ↗**, which navigates to this add-on's page in Home Assistant where Restart actually lives.
- **note**: even had it authenticated, it was the wrong shape. A control served *by* this container cannot rescue this container when its terminal is wedged, which is the only situation anyone reaches for it. The dependable path is a Home Assistant script calling `hassio.addon_restart`, which runs in HA Core — see DOCS.md.
- **not shipped**: a voice-input button. Claude Code has `/voice` built in, so it would have been pure duplication. Caught before it was built.

## 0.1.5 — 2026-07-27

- **new**: persistent top bar above the terminal, showing the add-on name and version with **Reconnect** and **Restart add-on** buttons. No new services, no new ports, no new dependencies.
- **new**: `usr/local/bin/build-ttyd-shell` generates the shell at boot. ttyd 1.7.7 serves exactly one self-contained ~730 KB page and mounts it into `document.body` — there is no `/terminal` route to iframe, and `--index` *replaces* the terminal rather than wrapping it. So the generator starts a throwaway ttyd on loopback, fetches ttyd's own page, and splices our style and script into it. Re-extracting on every boot means this tracks ttyd upgrades instead of pinning us to one version's markup.
- **fix**: if the shell fails to build for any reason, ttyd starts without `--index` and serves its stock UI. A broken top bar must never cost someone their terminal.
- **note**: the bar is created in JavaScript after page load, not written into the static HTML. ttyd mounts with preact via `render(h(App), document.body)`, which diffs against body's existing children — a static `<div>` there gets claimed and stripped, rendering as an empty unstyled strip. A watchdog re-adds the bar if it ever disappears. Styles are literal values with `!important` rather than CSS custom properties, since this stylesheet lands in a page we don't own.
- **known limitation**: the Restart button posts to `/api/hassio/addons/self/restart` using the browser's HA session. This is unverified — HA's API authenticates by `Authorization: Bearer`, not cookies, so it may return 401. The reliable path is the HA-side `hassio.addon_restart` service, which runs in HA Core and therefore still works when this container is wedged — which is the situation you actually reach for it in. A button served by the add-on cannot rescue the add-on.

## 0.1.4 — 2026-07-27

- **fix**: scrolling in the browser terminal, properly this time. The cause was never mouse mode on its own — it was that tmux drives the outer terminal's **alternate screen**, which xterm.js gives no scrollback and where it translates wheel events into arrow keys. In a Claude Code session that meant scrolling up walked backwards through your own message history. `terminal-overrides` now strips the alternate-screen capability (`smcup@:rmcup@`) so tmux writes to the normal buffer, xterm.js owns the scrollback, and the wheel scrolls the page with a real scrollbar.
- **change**: `set -g mouse off` is required alongside it — with mouse on, tmux captures the wheel for copy-mode and it never reaches xterm.js. The two settings only work as a pair, and the file says so at length so neither gets "cleaned up" in isolation.
- **fix**: text selection, as a side effect of the same change. With mouse on, tmux captured drag events for its own selection, so click-dragging in the browser deselected immediately and users had to hold shift to bypass tmux. Normal click-drag selection now works.
- **note**: side effects — exiting or detaching tmux no longer restores prior screen contents, and click-to-focus-pane / drag-to-resize are gone. `history-limit 100000` is kept for keyboard copy-mode (`Ctrl+A` then `[`).

Credit: OG-Che spotted that Claude Terminal Pro scrolls correctly and this add-on didn't, which started the hunt. The actual mechanism came from Ahmad's description of the failure — *"it went up through the lines I sent, like if I pressed up"* — which is specifically what xterm.js does on the alternate screen, and is what identified the real cause after a first attempt (`mouse off` alone) made it worse. Verified by a scrollbar appearing in the browser, not by reading the config back.

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
