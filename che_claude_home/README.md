# CHE Claude in HomE Assistant

Home Assistant add-on: run Anthropic's [Claude Code](https://claude.ai/code) CLI in a web terminal, with resilience baked in from the start.

## Why another Claude Code add-on?

Because the community add-ons that came before this one (particular respect to [ESJavadex/claude-code-ha](https://github.com/esjavadex/claude-code-ha), which was the launchpad) are solid but leave a lot to configure at runtime — persistent auth, tmux wrapping, PATH tricks, MCP config seeding, and so on. This add-on bakes those in as first-class defaults.

## Features

- **Sessions survive everything.** tmux wrapper means your Claude conversation stays alive across browser tab close, iframe reload, and add-on restart.
- **Real persistent storage.** Everything auth, settings, npm, apk, Python venvs, skills, MCP config lives in `/data`, HA's only guaranteed-persistent path.
- **Real terminal scrollback.** 100k line buffer + tmux mouse mode on. No more PageUp/PageDown gymnastics.
- **First-class HA helpers baked in.** `hac` for HA REST calls, `persist-install` for durable packages, session picker for multi-session workflows.
- **Choose your Claude Code version.** Bake it with the image (safe), latest npm (bleeding edge), or pin an exact version (rollback safety net).
- **Opt-in feature toggles.** WhatsApp bridge, Playwright browser, image paste — off by default, on when you want them.

## Install

See the repository [README](../README.md) for instructions on adding this add-on repository to your HA instance.

## Documentation

Full docs render inside the HA add-on info page — see [DOCS.md](./DOCS.md).

## License

MIT. See [LICENSE](../LICENSE).

## Credits

Built on ideas from [ESJavadex/claude-code-ha](https://github.com/esjavadex/claude-code-ha) and [heytcass/home-assistant-addons](https://github.com/heytcass/home-assistant-addons). Thanks to Anthropic for making Claude Code such a joy to build around.
