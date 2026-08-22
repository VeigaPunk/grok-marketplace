# grok-bot surface for xbgst

grok-bot is not the judge. This skill is a local-exec trigger into Grok Build (`grok -p`). do not rewrite Electron.

## Install

From the marketplace root:

```bash
bash plugins/xbgst-stack/integrations/grok-bot/install-grok-bot-surface.sh
bash plugins/xbgst-stack/integrations/grok-bot/bin/xbgst-surface-doctor.sh
bash plugins/xbgst-stack/integrations/grok-bot/bin/xbgst-surface-restart.sh   # applies CDP flags
```

Idempotent. Installs:

- `$HOME/.agents/skills/xbgst-surface` → this directory
- `$HOME/.grokbot/workflows/xbgst-surface/` (grok-bot workflow library)
- CDP flags in `~/.config/grok-bot-flags.conf` (`--remote-debugging-port=9333`)

Does not write `~/.grokbot/settings.json`. Does not create `~/.cursor`. Keep `localToolPermission=always` (already set on this host).

## Ping

```bash
bash plugins/xbgst-stack/integrations/grok-bot/bin/xbgst-surface-ping.sh
```

Expect stdout: `xbgst armed`.

## Operator steps

1. Open `/home/vgpnk/Projects/xbgst/grok-marketplace/plugins/xbgst-stack/integrations/grok-bot` as the grok-bot folder (`integrations/grok-bot`, not the judge). Do not open the hangar or grok-marketplace root — those glob `**/SKILL.md` onto the judge skill `name: xbgst`.
2. Run the install command above.
3. In grok-bot, say `xbgst <task>` (or ping first).
4. The skill local-execs `grok -p` with `/xbgst <task>` on hangar `--cwd` `/home/vgpnk/Projects/xbgst`. FALLBACK.md is equal-class — if local-exec cannot spawn `~/.grok/bin/grok`, paste FALLBACK immediately. Do not invent MCP/gdsd.

Inspect uses `grok --cwd /home/vgpnk/Projects/xbgst inspect` (never `grok inspect --cwd`).

## Inject from Grok Build (HERE → THERE)

Do not Open Folder on the hangar. From this host, paste into the live Grok Bot composer:

```bash
bash plugins/xbgst-stack/integrations/grok-bot/bin/xbgst-surface-inject.sh <<'EOF'
You are not the judge. Local-exec, do not talk first:
…
EOF
```

Uses `hyprctl` `class:grok-bot` + **SHIFT+Insert** (this host's paste) + **CTRL+Return** (bare Return is a newline in the multiline composer). `--dry-run` prints the dispatchers. `--no-submit` pastes without sending. Does **not** start `grok -p` itself — grok-bot local-execs that.

See `PROTOCOL.md`.

## Gates

From marketplace root:

```bash
bash plugins/xbgst-stack/integrations/grok-bot/tests/test-surface-ping.sh
bash plugins/xbgst-stack/integrations/grok-bot/tests/test-surface-grok-argv.sh
bash plugins/xbgst-stack/integrations/grok-bot/tests/test-surface-install.sh
bash plugins/xbgst-stack/integrations/grok-bot/tests/test-surface-identity.sh
bash plugins/xbgst-stack/integrations/grok-bot/tests/test-surface-inject.sh
```
