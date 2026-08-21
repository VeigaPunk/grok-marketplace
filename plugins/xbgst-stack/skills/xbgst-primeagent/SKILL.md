---
name: xbgst-primeagent
description: >
  Optional L2-loop substrate adapter for xbgst-stack. Routes long-running specialist
  work through scripts/prime-agent-l2.sh → user-level prime-agent (xAI only).
  Triggers: primeagent, prime-agent, L2-loop, xbgst-primeagent.
---

# xbgst-primeagent

**Optional L2-loop** host substrate. Not the L1 judge. Not L3 sekhmet. Not L2-select (xbrd-selector).

## Call path

`gx-*` specialist → this skill / `/xbgst-primeagent` → `scripts/prime-agent-l2.sh` → `prime-agent`.

Parent is always the calling `gx-*`. Do not tell PrimeAgent "You are gx-…". `rlm()` children are PrimeAgent sessions (allowed). Grok spawn stays named types only.

## When to call

Already-spawned `gx-*` may shell the wrapper for reattach / `/refine`. First ticks are tools: `-p` or `--mode json|rpc`. This skill is **not** the L1 judge and does not run Pareto or ship. `--autonomous` is a PrimeAgent mode, not an xbgst scheduler — parent `gx-*` keeps spawn/Pareto. Sessions: `PRIME_AGENT_SESSION_DIR=$HOME/.xbgst/prime-agent/sessions`.

Skip for judge rounds, one-shot labrat probes, and 64-wide sekhmet swarms.

## Three skill planes (do not collapse)

| Plane | Writes | Who |
|---|---|---|
| Grok `create-skill` | `SKILL.md` under `~/.grok/skills` | grok parent / create-skill |
| PrimeAgent `/refine` | harness lesson snapshots + rollback | inside L2-loop only |
| PrimeAgent `skill-creator` | kernel Python under `~/.prime/agent/skills` | inside L2-loop |

`/refine` does **not** replace grok `create-skill` and must **not** write `~/.grok/skills`. Discover grok skills read-only via the grok parent.

## Safety

> Prime Agent executes model-generated Python and project commands with your user permissions. Its worker and kernel processes improve lifecycle isolation and recovery; they are **not** a security sandbox.

- xAI only (`--provider xai`). Fail-closed without `XAI_API_KEY` (exit 2 / `PRIME_TICK_BLOCKED_NO_XAI` → escalate E5). Refuse `auth.json` with anthropic/openai. Never `/login`.
- **BANNED:** never spawn `general-purpose` or `explore`. Do not spawn grok subagents from the kernel.
- First ticks only in disposable cwd `/tmp/xbgst-prime-*`. Never xbgst `main`.
- Kernel/auth stay in `~/.prime/agent/`. Telemetry off (`PRIME_AGENT_TELEMETRY=0`, `DO_NOT_TRACK=1`).
- Never exec host `pi` — wrapper requires basename `prime-agent`.

## Install

User-level official installer, pin **0.7.4**. Adapter is markdown + POSIX sh only; do not vendor `prime-agent`.
