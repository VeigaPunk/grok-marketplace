---
name: the-janitor
description: >
  Global secrets janitor for 1Password CLI (op) and CDP browser-extension bridge.
  Use when the user needs to store, fetch, inject, or run with API keys / tokens /
  passwords / credentials; wire op:// references; clean secrets out of source or
  .env; enable 1Password extension on musketeer-chrome CDP; or avoid committing
  secrets. Triggers: the-janitor, 1password, op CLI, secrets, credentials, API
  key, token, op://, op run, inject secrets, cdp-bridge, 1password extension,
  never commit secrets. Prefer spawning subagent_type the-janitor or running op
  / the-janitor per this skill. Desktop-app unlock — no KEYNEST_PASSWORD.
compatibility: >
  Requires op on PATH and 1Password desktop CLI integration (or
  OP_SERVICE_ACCOUNT_TOKEN). CDP extension path also needs musketeer-chrome
  burner profile + NativeMessagingHosts BrowserSupport + 1Password app unlocked.
metadata:
  short-description: "1Password (op) secrets janitor + CDP extension bridge"
  author: local
---

# the-janitor (1Password CLI + CDP extension)

Local secret hygiene via **`op`** and, when automating browsers over CDP, a
working **1Password browser extension ↔ desktop app** bridge on the
**musketeer-chrome** burner profile. Keep secrets out of source, logs, prompts,
and LLM context. Inject at runtime. Prefer desktop-app unlock so you are **not**
typing a vault password for every command.

## When this skill applies

- User mentions secrets, API keys, tokens, credentials, 1Password, `op://`, or keynest migration
- You are about to hardcode a secret or write a `.env` with real values
- A command needs secrets as environment variables
- CDP / musketeer / agent-browser login or autofill needs the **1Password extension**
- User says **the-janitor** or `/the-janitor`

## Preferred dispatch

1. **Spawn the agent** (best for multi-step secret work). Before the call, read
   the complete bytes of the packaged xbgst-stack
   `../../ssot/godspeed-core/directive.md`. A host overlay is valid only when it
   is byte-identical to that packaged file. Prepend those bytes verbatim to the
   task, remove any terminal copies of `| godspeed` from the task body, and
   append exactly one final `| godspeed`. Fail closed if the packaged directive
   cannot be read; never transcribe or shorten it.

```
spawn_subagent(
  subagent_type="the-janitor",
  description="[the-janitor] secrets op",
  capability_mode="execute",
  prompt="<verbatim bytes read from ../../ssot/godspeed-core/directive.md>\n\n<task: list/read-into-process/run/inject/cdp-bridge...; never echo secret values>\n| godspeed"
)
```

The `prompt` value above describes construction, not replacement text: the
actual dispatched prompt begins with the file's bytes and ends with the literal
suffix exactly once. Apply the same construction to every follow-up or resume.

2. **Or run `op` / `the-janitor` yourself** for a one-liner (same safety rules).

## Prerequisites (once per machine)

Desktop path (recommended — unlock app / biometrics, not endless passwords):

1. Open **1Password** desktop app and unlock it.
2. **Settings → Security**: enable system authentication (fingerprint / polkit) if available.
3. **Settings → Developer**: enable **Integrate with 1Password CLI**.
4. In a terminal: `op signin` (approve in the app if prompted), then `op whoami`.

Headless / pure SSH without GUI:

```bash
export OP_SERVICE_ACCOUNT_TOKEN='...'   # from 1Password service account
op whoami
```

Do **not** use keynest or `KEYNEST_PASSWORD` for this agent anymore.

## CDP + 1Password extension (musketeer-chrome)

Custom `--user-data-dir` Chrome **does not** inherit daily-browser
`NativeMessagingHosts`. Without a host under the burner profile, the extension
is installed but **cannot** talk to desktop 1Password via BrowserSupport.

| Piece | Expected |
|-------|----------|
| Burner profile | `~/.local/share/the-musketeer/chrome-profile` |
| Extension | 1Password Nightly `gejiddohjgogedgjnonbofjigllpkmbf` (or stable `aeblfdkhhhdcdjpifhhbdiojplfjncoa`) |
| NMH | `$PROFILE/NativeMessagingHosts/com.1password.1password.json` → `/opt/1Password/1Password-BrowserSupport` |
| Launcher | `musketeer-chrome` installs/refreshes NMH on every launch |
| Helper | `the-janitor cdp-bridge ensure` \| `status` \| `open-popup` |
| CDP | `http://127.0.0.1:9222` |

```bash
# wire + report (names/status only — no secrets)
the-janitor cdp-bridge ensure
the-janitor cdp-bridge status

# open extension popup on live CDP (human unlock / connect; never scrape vault DOM)
the-janitor cdp-bridge open-popup
```

**When NMH was just added:** restart musketeer-chrome so the extension reloads BrowserSupport.

**Agent policy on CDP logins:**

1. Prefer **pre-authenticated tabs** (human + extension once) for product sites.
2. Prefer **CLI injection** (`op run` / `the-janitor run`) for non-browser secrets.
3. If the task must use the extension UI: ensure bridge first, drive UI with
   `agent-browser --cdp …`, **never** dump field values into chat.
4. Do not copy secrets from the extension into agent transcripts.

## Safe recipes

```bash
# auth / inventory (names only)
op whoami
# or: the-janitor whoami
op vault list
op item list --vault Personal

# CDP extension bridge
the-janitor cdp-bridge ensure
the-janitor cdp-bridge status

# run a command with secrets injected from a template env file
# .env.tpl example:
#   API_KEY=op://Personal/My API/credential
op run --env-file=.env.tpl -- docker compose up
# or: the-janitor run --env-file=.env.tpl -- docker compose up

# one-off env injection
API_KEY=op://Personal/My\ API/credential op run -- \
  curl -sS -H "Authorization: Bearer $API_KEY" https://api.example.com

# read into a pipe (never cat to chat)
op read "op://Personal/My API/credential" | some-consumer

# materialize a config from a template (warn: file may be plaintext)
op inject -i config.tpl -o /tmp/config.local
```

## Hard rules (always)

| Do | Don't |
|----|--------|
| `op run` / `op inject` / pipe `op read` | Print `op read` / `--reveal` output in chat |
| Report vault / item / field **names** | Echo secret values, tokens, session material |
| Use `op://Vault/Item/field` in templates | Commit real `.env` secrets |
| `the-janitor cdp-bridge ensure` before CDP autofill | Scrape 1Password extension DOM into chat |
| Stop if `op whoami` fails | Invent passwords or service-account tokens |

## Response shape

Short status only:

- vaults / items / fields referenced (names)
- command executed under `op run` (without secret expansion)
- CDP bridge: NMH / extension id / desktop / CDP reachability
- blockers (app integration off, locked app, missing service account, missing NMH)

Never include secret material in the final message.
