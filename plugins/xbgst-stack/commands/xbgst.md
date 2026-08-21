---
description: Grok-native godspeed orchestrator — spawn the-planner then judge rounds (local-first → main). No xask.
argument-hint: <task for the judge>
---

# /xbgst — Grok-native godspeed

You are on **Grok Build**. This command is the Grok host path of xbrd-godspeed.

## Do this immediately

1. Load skill **xbgst** (`Skill` / skill file under the installed plugin or `~/.grok/skills/xbgst`).
2. Follow that skill exactly for `$ARGUMENTS` (or the user task).
3. **Round 0:** spawn `the-planner` first. Planner **loads skill `wwkd`**. Wait for plan artifact.
4. Then judge: name axes → parallel specialists (always include `connector`) → Pareto → ship on APPROVED.

## Hard rules (Grok host)

- **No xask / no Claude TeamCreate** as the default path. Spawn native Grok subagent types from this plugin (`scout`, `reviewer`, `labrat`, `executor`, `connector`, `distiller`, `simplifier`, `the-revenger`, `sentinel`, `critic`, `mutation-tester`, `scribe`, `the-planner`, `the-janitor`, …). **Exception E2:** dispatch `the-revenger` as `cdx-revenger-*` via stock `codex exec` (never `codex-titanium`; Titanium is sekhmet L3 only). `gx-revenger-*` inherit remains the fallback.
- **Never** `general-purpose` or `explore` (banned; livepatch hard-bans them).
- **Local-first:** after each judged milestone APPROVED → commit project files → `git push -u origin main` (SSH). No fork→PR default. No force-push of `main`.
- **Language:** match the repo. No Rust lock.
- **Connector** mandatory every PROPOSE round after Round 0.
- Godspeed injection on every teammate: prepend byte-exact `ssot/godspeed-core/directive.md` (quintessential subagent form).

## Optional substrate route

L1 remains the Grok judge and sole scheduler/integrator. Default to named native `gx-*` specialists. Route long-lived intermodel work to an existing OpenAI-backed PrimeAgent only as an attachable **L2-loop**; first name a `gx-*` route owner and send `route_id`, `parent`, `task`, `scope`, `allowed_actions`, `return`, and `stop`. The return is evidence for L1, never a Pareto/`APPROVED`/ship decision. Do not allow PrimeAgent child fan-out unless the route says so.

Use `xbrd-selector` only as the separate L2-select lane when it is installed; PrimeAgent never substitutes for it. Use sekhmet only as an explicit bounded L3 escalation; PrimeAgent never proxies L3 and never invokes `codex-titanium`. If PrimeAgent or its user-owned OpenAI ChatGPT/Codex OAuth is absent, continue through the native `gx-*` path. Never require PrimeAgent in the host inventory or installer. See skill **xbgst-primeagent** for attach/send/resume mechanics.

## Aliases

| Command | Meaning on Grok |
|---------|-----------------|
| `/xbgst` | Full stack (this file → skill) |
| `/xgs` | Same skill, emphasize fast parallel rounds |
| `/xbt` / `/xbreed` / `/xb` | Same skill; cross-model xask is **optional/off** unless host has xask and user asks. Consult table: `commands/references/xbreed-shared.md` |

## Livepatch

Bundled under this plugin. Prefer `/xbgst-livepatch` or skill **xbgst-livepatch** after first install.

## Not in this marketplace

`heuer-planning` is on **ds4cc**, not xbgst-stack. Critic inlines ACH-style methods if the skill is absent.
