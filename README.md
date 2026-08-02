# CHE Home Assistant Add-ons

**Built by Ahmad Dee, 2026.**

A small collection of Home Assistant add-ons focused on making Claude Code feel native inside HA — persistent, resilient, and out of your way.

## Add-ons in this repository

### [CHE Claude in HomE Assistant](./che_claude_home)

The main event. A web-based terminal that runs Anthropic's [Claude Code](https://claude.ai/code) CLI inside your Home Assistant instance, with resilience baked in from day one:

- **Sessions survive restarts** — tmux-wrapped so a tab close, iframe reload, or add-on restart doesn't kill your conversation
- **Real persistent storage** — auth, settings, npm packages, apk packages, Python venvs, and skills all live in `/data`, safe across container rebuilds
- **First-class helpers** — `hac` (HA REST wrapper), `persist-install`, session picker, all baked in, no re-bootstrapping every session
- **Real terminal scrollback** — mouse wheel works, 100k line buffer, no PageUp/PageDown gymnastics
- **User's choice of Claude version** — baked-with-image (safe), latest-npm (bleeding edge), or pinned-version (rollback safety net)
- **Optional feature toggles** — WhatsApp bridge, Playwright, image paste — opt-in, not always-on

See the [add-on directory](./che_claude_home) for install instructions and full docs.

## Installing this repository

In Home Assistant:

1. **Settings** → **Add-ons** → **Add-on Store**
2. Click the ⋮ menu (top right) → **Repositories**
3. Add: `https://github.com/ahmaddee/che-hass-addons`
4. **CHE Claude in HomE Assistant** should appear under a new "CHE Add-ons" section
5. Click it, then **Install**

## License

MIT — use it, change it, ship it, sell it. See [LICENSE](./LICENSE).

## Contributing

Issues and PRs welcome. This is a personal project maintained by [@ahmaddee](https://github.com/ahmaddee), but the goal is to make it useful to anyone running Claude Code inside Home Assistant.
