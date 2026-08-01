---
description: Grok-native godspeed orchestrator — spawn the-planner then judge rounds (local-first → main). No xask.
argument-hint: <task for the judge>
---

# /xbgst — Grok-native godspeed

You are on **Grok Build**. This command is the Grok host path of xbrd-godspeed.

## Do this immediately

1. Load skill **xbgst** (`Skill` / skill file under the installed plugin or `~/.grok/skills/xbgst`).
2. Follow that skill exactly for `$ARGUMENTS` (or the user task).
3. **Round 0:** spawn `the-planner` first (WWKD). Wait for plan artifact.
4. Then judge: name axes → parallel specialists (always include `connector`) → Pareto → ship on APPROVED.

## Hard rules (Grok host)

- **No xask / no Claude TeamCreate** as the default path. Spawn native Grok subagent types from this plugin (`scout`, `reviewer`, `labrat`, `executor`, `connector`, `distiller`, `simplifier`, `the-revenger`, `sentinel`, `critic`, `mutation-tester`, `scribe`, `the-planner`, `the-janitor`, …).
- **Never** `general-purpose` or `explore` (banned; livepatch hard-bans them).
- **Local-first:** after each judged milestone APPROVED → commit project files → `git push -u origin main` (SSH). No fork→PR default. No force-push of `main`.
- **Language lock in skill:** Rust-only for generated scripts/tooling when the skill says so.
- **Connector** mandatory every PROPOSE round after Round 0.
- Godspeed injection on every teammate (short 4-rule block from the skill).

## Aliases

| Command | Meaning on Grok |
|---------|-----------------|
| `/xbgst` | Full stack (this file → skill) |
| `/xgs` | Same skill, emphasize fast parallel rounds |
| `/xbt` / `/xbreed` / `/xb` | Same skill; cross-model xask is **optional/off** unless host has xask and user asks |

## Livepatch

Bundled under this plugin. Prefer `/xbgst-livepatch` or skill **xbgst-livepatch** after first install.

## Not in this marketplace

`heuer-planning` is on **ds4cc**, not xbgst-stack. Critic inlines ACH-style methods if the skill is absent.
