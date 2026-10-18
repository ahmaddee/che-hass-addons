## 0.1.18

**An add-on restart threw you into a blank conversation, and the session picker could quietly run an older Claude Code.**

- **new**: `resume_last_conversation` (default **on**). Auto-launch now resumes your last conversation
  (`claude --continue`), so a restart or update lands you back where you were. It falls back to a fresh
  conversation only when `--continue` fails fast (nothing to resume). A resumed session that ends in Ctrl-C
  or a crash exits to the session picker instead of opening a new, empty conversation. A naive
  `--continue && exit 0` gets that wrong, and two installs hit it in the wild on 2026-10-18.
- **fixed**: the session picker resumed with the **image's baked** Claude Code while auto-launch used the
  npm-installed one: a silent downgrade, reported from a second install as "2.1.223 doesn't support
  this model". Both now go through the new `claude-launch`, which asks every installed copy for
  `--version` and runs the highest one that answers.
- **note**: picker choices are unaffected by `resume_last_conversation`; "new conversation" is always new.

## 0.1.17

**Every restart with `enable_playwright` re-downloaded 857 MiB and served a 502 for 15 minutes.**

- **fixed**: `persist-install` ran `apk add --no-cache`, which discards both the package index and
  every `.apk` the instant the install finishes. Nothing under `/usr` survives container
  recreation, so on each start the packages were gone *and* had to be pulled from the network
  again. With `enable_playwright: true` that was 857 MiB across 178 packages, measured at
  **15m 21s** on 2026-08-06.

  s6 runs every `cont-init` script to completion before starting any service, so `ttyd` — and the
  entire web terminal — cannot come up until that finishes. Home Assistant's ingress has nothing
  to proxy to and serves a bare **502 Bad Gateway**. It is indistinguishable from a crashed
  add-on, and it happened on every single restart.

  Now uses `apk add --cache-dir /data/apk-cache`. `/data` survives, so the first install still
  downloads and every install after unpacks from local disk with no network. Override with
  `APK_CACHE_DIR`; `rm -rf /data/apk-cache` is always safe and only slows the next install.

- **note**: the file-copy step in `persist-install` never solved this and was never going to. It
  copies only `/usr/bin`, `/usr/sbin`, `/bin` and `/usr/lib/*.so*`. Chromium is a 238 MB
  *directory* at `/usr/lib/chromium` behind a symlink, needing 151 external shared libraries — so
  the copy preserved a broken symlink and missed the entire payload. The cache is what actually
  persists it.

- **changed**: `45-playwright.sh` now says out loud which path it is on — "installing from local
  cache, no download" versus a warning that the terminal will 502 for 10–20 minutes and that this
  is **not** a crash. Silence during a quarter-hour outage was the worst part of the bug.

## 0.1.16

**`enable_playwright` never actually delivered browser tools. Instance #8 of the house bug.**

- **fixed**: `45-playwright.sh` wrote `mcpServers.playwright` into `.claude/settings.json`. Claude
  Code does not read MCP servers from `settings.json` — only from `~/.claude.json` and `.mcp.json`.
  So with `enable_playwright: true` the browser installed (~857 MiB), the log said "Ready", and no
  browser tools ever appeared. The option was read, the work was done, and the result was filed
  somewhere nothing looks.

  It was worse than merely inert. `30-skills-mcp.sh` runs first in lexical order and *deletes*
  `.mcpServers` from `settings.json` — precisely because that key is dead there — and then this
  script wrote it straight back into the same dead file. Two scripts pulling in opposite directions
  on a key neither could make work.

  Same root cause as `enable_mcp_defaults` in 0.1.13: **written correctly, read from somewhere
  else.** Found by checking which file each script targets rather than trusting that a toggle wired
  to code is a toggle that works.

- **added**: one-time migration removing the inert `mcpServers.playwright` from `settings.json`,
  backed up to `settings.json.bak-playwrightmove` rather than silently dropped.

- **changed**: the playwright write is now atomic (`mktemp -p` + `mv -f`) and guards against invalid
  JSON, matching `30-skills-mcp.sh`. The "already configured — leaving user config untouched" check
  is preserved, so swapping `--isolated` for `--user-data-dir` to keep browser logins across sessions
  survives upgrades.

- **docs**: both READMEs advertised a **WhatsApp bridge** feature toggle. There is no WhatsApp
  anywhere in this add-on — `enable_wa_watcher` was removed in 0.1.12 for being read by nothing, and
  the READMEs kept selling it anyway. Also corrected "opt-in, not always-on": only
  `enable_playwright` defaults to false.

## 0.1.15

**Review pass on 0.1.13/0.1.14 — user-config preservation, atomic writes, and visibility.**

- **changed**: the `homeassistant` entry is now written with surgical field assignment rather than
  wholesale replacement. `//=` initialises only what's missing, so a user's extra headers and their
  own `timeout` survive; only `url` and `headers.Authorization` are managed. Overwriting the
  credential is a repair rather than a stomp — that URL is the Supervisor proxy, which accepts
  `SUPERVISOR_TOKEN` and 401s anything else, so it is the only value that can work there.

- **fixed**: all config writes are now atomic (`mktemp -p` in the target directory + `mv -f`).
  Previously a crash mid-`cat` could leave a truncated `~/.claude.json` — recoverable, since the next
  boot's validity guard would skip it, but Claude Code couldn't read it in the meantime. `mktemp -p`
  matters: the default `/tmp` is tmpfs, and a cross-filesystem `mv` silently degrades to copy+unlink
  and loses atomicity.

- **added**: DOCS gains a **First-boot behaviour** section, and the boot log now states plainly what
  was configured, that access is gated by Voice-assistant exposure (empty by default), and how to
  turn it off. Auto-wiring on install is a reasonable default; doing it invisibly is not.

Credit: OG-Che reviewed 0.1.14 and caught the header-clobbering and non-atomic write. The exposure
gate is what makes `enable_mcp_defaults: true` a defensible default — MCP is wired for you, but the
house stays shut until you open specific entities yourself.

## 0.1.14

**Refines 0.1.13: the Home Assistant credential is now a reference, not a value.**

- **changed**: the seeded `homeassistant` entry stores the literal string
  `"Bearer ${SUPERVISOR_TOKEN}"` rather than the expanded token. Claude Code performs environment
  variable expansion in user-scoped `~/.claude.json` entries — `headers` is explicitly among the
  supported fields — so it resolves to the live token at load time.

  Why it matters: Supervisor mints a **new** token on every add-on start (`secrets.token_hex(56)`),
  so 0.1.13's literal write had to be refreshed on every boot to stay valid. Referencing instead of
  embedding removes the need for any refresh at all — there is no stale state to go stale.

  It's also better security posture: the token never lands on disk, never in a backup, never in a
  diff or a screenshot. It exists only in the running container's environment.

  If `SUPERVISOR_TOKEN` were somehow unset, the config still loads: Claude Code reports a
  missing-variable warning in `claude mcp list` and passes the literal text through, which fails
  cleanly with a 401 rather than crashing.

- **general rule this produced**: *anything derived from a per-boot value must be refreshed per boot —
  unless you can reference it instead of embedding it, in which case the refresh problem disappears.*
  Prefer the reference. It converts "must remember to refresh" into "no refresh is possible or
  needed."

## 0.1.13

**Home Assistant control now works out of the box — no token, no setup.**

- **added**: `homeassistant` MCP server is registered automatically, pointed at HA's stateless
  Streamable HTTP endpoint via the Supervisor proxy (`http://supervisor/core/api/mcp`) using the
  add-on's own credentials. No long-lived token to mint, no IP address to configure — `supervisor`
  is a fixed internal hostname, so it is identical on every install. The credential is **refreshed
  on every start**, because Supervisor issues it per container start; a first-boot-only guard would
  bake in a token that goes stale on the next restart.

- **fixed**: `enable_mcp_defaults` wrote its config to `~/.claude/settings.json`, but Claude Code
  reads MCP servers only from `~/.claude.json`. **The option has therefore done nothing on every
  install that has ever existed** — the file was written, the log said "Writing default MCP config",
  and no server was ever registered. Now targets `~/.claude.json`, merged with `jq` and written
  atomically so the OAuth session and project state in that file are never disturbed. Any inert
  `mcpServers` block left in `settings.json` is removed (backup kept alongside).

  Third instance of this failure shape in this add-on: something written correctly, and the thing
  meant to consume it looking somewhere else. See also the `.tmux.conf` written to `/root` while
  `HOME` was `/data/home` (0.1.2), and the `uvx` time server that pointed at a binary this image
  does not ship (0.1.3).

- **why stateless matters**: HA's legacy `/mcp_server/sse` endpoint holds an in-memory session, so
  restarting Home Assistant makes every subsequent MCP call fail with a 404 until the client
  reconnects — with no error a user could interpret. The stateless endpoint has no session to
  invalidate. Verified by restarting HA Core and confirming the next call succeeded. MCP spec
  revision 2026-07-28 removes protocol-level sessions entirely and deprecates HTTP+SSE, so this is
  also where the standard is going.

- **added**: per-server `timeout` (15 min) on the Home Assistant entry. Claude Code aborts a tool
  call that has been idle for 5 minutes on HTTP transports; HA scripts holding an internal delay
  trip that and report a false failure while still running perfectly. Requires Claude Code
  >= 2.1.203.

- **changed**: users who have repointed `homeassistant` at their own instance are detected by URL and
  left completely alone.

# Changelog

## 0.1.12 — 2026-07-27

- **fix**: the 0.1.4 scrolling fix never reached anyone who already had a `/data/home/.tmux.conf`. `10-env.sh` seeded it with a `[ ! -f ]` guard — first boot only — so the corrected config sat unread in `/root/` for eight releases while the stale one kept `mouse on` with no alternate-screen override. Every apparent fix afterwards was a live `tmux set`, discarded by the next restart, which is exactly why the bug presented as intermittent and unreproducible.
- **fix**: `10-env.sh` now repairs that one known-broken shape — `mouse on` **and** no `smcup@` — after backing it up to `.tmux.conf.bak-premouse`. That combination cannot scroll in a browser (tmux captures the wheel for copy-mode, xterm.js never sees it), so it is never a deliberate choice. Any other config, including customisations that keep `mouse on` intentionally alongside the override, is left untouched.
- **note**: the giveaway was a yellow timestamp and line count in the top-right corner — tmux's copy-mode indicator. Nothing else draws that, and it identified the cause immediately after two wrong diagnoses.


## 0.1.11 — 2026-07-27

- **fix**: the sidebar icon rendered blank. `panel_icon` was `mdi:home-heart-outline`, which is not a real Material Design icon — there is no outline variant of `home-heart`. An invalid icon name fails silently and draws nothing. Changed to `mdi:home-heart`, which is already used seven times elsewhere in this Home Assistant install and renders correctly.


## 0.1.10 — 2026-07-27

- **fix**: reverts the wrong half of 0.1.8. `ingress_panel: true` is **not** a manifest field — Supervisor ignores it in `config.yaml`, so 0.1.8 shipped a key that did nothing while claiming to fix the sidebar. Whether an add-on appears in the sidebar is *user state*, toggled on the add-on page ("Show in sidebar") or set with `POST /addons/<slug>/options {"ingress_panel": true}`. The key is removed and the real mechanism documented in place.
- **note**: `panel_icon`, `panel_title` and `panel_admin` **do** work and always did. They are simply absent from the `/addons/<slug>/info` response, which makes them look inert when queried there. HA renders the panel as `title: "CHE Claude"`, `icon: mdi:home-heart-outline` — confirmed via the frontend's own `get_panels`. Ask HA what it is rendering, not Supervisor what it stored.

## 0.1.9 — 2026-07-27

- **removed**: `sidebar_title`. It was declared in the schema and read by nothing. It also cannot work as designed — `panel_title` is an add-on *manifest* field, and the Supervisor API returns 403 for manifest changes on a running install, so no runtime option can rename the sidebar entry. The name is now simply fixed at "CHE Claude".
- **removed**: `enable_wa_watcher`. Also read by nothing — the WhatsApp bridge isn't implemented yet. A toggle that silently does nothing is worse than an absent one; it'll come back when there's something behind it.
- **audit**: swept the whole rootfs for the pattern behind most of today's bugs — configuration written to one path and read from another, and options declared but never consumed. Every remaining option resolves to code that reads it, every hardcoded path either exists or is deliberately probed with `[ -f ]` as a legacy-migration check. The two above were the only genuine finds.

## 0.1.8 — 2026-07-27

- **fix**: the add-on never appeared in Home Assistant's sidebar. `panel_icon`, `panel_title` and `panel_admin` were all declared in `config.yaml`, but `ingress_panel: true` — the field that actually asks for a panel — was missing, so all three were inert. Reaching the terminal meant going through Settings → Add-ons → Open Web UI every time. Now appears as **CHE Claude** with `mdi:home-heart-outline`.
- **note**: `panel_*` are manifest fields, so this cannot be patched on a running install — the Supervisor API returns 403 for manifest changes. It takes an add-on update to land.

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
