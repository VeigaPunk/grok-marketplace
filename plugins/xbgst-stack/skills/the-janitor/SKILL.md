---
name: the-janitor
description: >
  Global secrets janitor for 1Password CLI (op). Use when the user needs to
  store, fetch, inject, or run with API keys / tokens / passwords / credentials;
  wire op:// references; clean secrets out of source or .env; or avoid
  committing secrets. Triggers: the-janitor, 1password, op CLI, secrets,
  credentials, API key, token, op://, op run, inject secrets, never commit
  secrets. Prefer spawning subagent_type the-janitor or running op per this skill.
  Desktop-app unlock — no KEYNEST_PASSWORD.
compatibility: Requires op on PATH and 1Password desktop CLI integration (or OP_SERVICE_ACCOUNT_TOKEN).
metadata:
  short-description: "1Password (op) secrets janitor"
  author: local
---

# the-janitor (1Password CLI)

Local secret hygiene via **`op`**. Keep secrets out of source, logs, prompts,
and LLM context. Inject at runtime. Prefer desktop-app unlock so you are **not**
typing a vault password for every command.

## When this skill applies

- User mentions secrets, API keys, tokens, credentials, 1Password, `op://`, or keynest migration
- You are about to hardcode a secret or write a `.env` with real values
- A command needs secrets as environment variables
- User says **the-janitor** or `/the-janitor`

## Preferred dispatch

1. **Spawn the agent** (best for multi-step secret work):

```
spawn_subagent(
  subagent_type="the-janitor",
  description="[the-janitor] secrets op",
  capability_mode="execute",
  prompt="<task: list/read-into-process/run/inject...; never echo secret values>"
)
```

2. **Or run `op` yourself** for a one-liner (same safety rules).

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

## Safe recipes

```bash
# auth / inventory (names only)
op whoami
op vault list
op item list --vault Personal

# run a command with secrets injected from a template env file
# .env.tpl example:
#   API_KEY=op://Personal/My API/credential
op run --env-file=.env.tpl -- docker compose up

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
| Stop if `op whoami` fails | Invent passwords or service-account tokens |

## Response shape

Short status only:

- vaults / items / fields referenced (names)
- command executed under `op run` (without secret expansion)
- blockers (app integration off, locked app, missing service account)

Never include secret material in the final message.
