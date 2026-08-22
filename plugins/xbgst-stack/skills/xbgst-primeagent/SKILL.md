---
name: xbgst-primeagent
description: >
  Optional attachable L2-loop substrate for xbgst-stack intermodel work and bounded
  delegation. Uses an existing user-level PrimeAgent with OpenAI ChatGPT/Codex OAuth; the
  xAI-only wrapper remains a legacy compatibility path. Triggers: primeagent,
  prime-agent, L2-loop, xbgst-primeagent.
---

# xbgst-primeagent

**Optional L2-loop** host substrate. Not the L1 judge. Not L3 sekhmet. Not L2-select (xbrd-selector).

## Call path

Preferred OpenAI route: L1 `xbgst` assigns a named `gx-*` route owner → this skill / `/xbgst-primeagent` → existing user-level `prime-agent --provider openai-codex`. The route owner remains the parent and reports evidence to L1. Do not tell PrimeAgent "You are gx-…". Credentials and ChatGPT/Codex OAuth setup are user-owned; this skill never runs `/login`.

Legacy compatibility route: `gx-*` → `scripts/prime-agent-l2.sh` → xAI-only `prime-agent`. The wrapper is not the OpenAI entrypoint and stays fail-closed without `XAI_API_KEY`.

## Required route envelope

Every OpenAI L2-loop dispatch must state:

```yaml
route_id: <stable id>
parent: <named gx-* route owner>
task: <one bounded objective>
scope: <allowed paths and systems>
allowed_actions: <tools, messaging, and whether child fan-out is allowed>
return: <evidence/artifact schema and recipient>
stop: <done condition, budget/cap, and abort conditions>
```

Before the envelope, read the packaged `../../ssot/godspeed-core/directive.md`
at call time and prepend its byte-exact contents. Normalize terminal markers and
end the complete initial prompt with exactly one literal `| godspeed`. Apply the
same rule to every task-bearing `prime-agent send` or resume message. Structured
attach/list/control operations carry no task prompt and are exempt.

L1 is the sole scheduler, Pareto judge, `APPROVED` authority, integrator, and shipper. PrimeAgent returns evidence, not decisions. PrimeAgent is not L2-select and never substitutes for `xbrd-selector`; it is not L3 and never proxies sekhmet. Child fan-out is forbidden unless `allowed_actions` explicitly authorizes it. Concurrent writing routes must use disjoint paths or worktrees recorded in `scope`.

## When to call

Use this optional lane for long-running intermodel exchange, bounded delegated work, or a task that benefits from `prime-agent send`, `attach`, or resume. Every task-bearing message prepends the canonical directive and ends exactly once with `| godspeed`. Sessions may live under `~/.xbgst/prime-agent/sessions`. First ticks use tools such as `-p` or `--mode json|rpc`. `--autonomous` only continues the bounded L2 task; it does not become an xbgst scheduler. `/refine` is local harness learning, not L1 policy.

Skip judge rounds, ranked selection, one-shot labrat probes, and sekhmet swarms. If PrimeAgent, OpenAI ChatGPT/Codex OAuth, or the route is unavailable, return to the native named `gx-*` path. Absence never blocks L1 and never promotes L2.

## Three skill planes (do not collapse)

| Plane | Writes | Who |
|---|---|---|
| Grok `create-skill` | `SKILL.md` under `~/.grok/skills` | grok parent / create-skill |
| PrimeAgent `/refine` | harness lesson snapshots + rollback | inside L2-loop only |
| PrimeAgent `skill-creator` | kernel Python under `~/.prime/agent/skills` | inside L2-loop |

`/refine` does **not** replace grok `create-skill` and must **not** write `~/.grok/skills`. Discover grok skills read-only via the grok parent.

## Safety

> Prime Agent executes model-generated Python and project commands with your user permissions. Its worker and kernel processes improve lifecycle isolation and recovery; they are **not** a security sandbox.

- OpenAI lane: use only existing user-owned ChatGPT/Codex OAuth (`openai-codex`). Never run `/login`, copy credentials, or make the plugin configure providers. Missing auth means native `gx-*` fallback.
- Legacy wrapper lane: `scripts/prime-agent-l2.sh` remains xAI-only and fail-closed without `XAI_API_KEY` (`PRIME_TICK_BLOCKED_NO_XAI`). Do not bypass its provider/auth guards.
- **BANNED:** never spawn `general-purpose` or `explore`. Do not spawn grok subagents from the kernel.
- First ticks only in disposable cwd `/tmp/xbgst-prime-*`. Never xbgst `main`.
- Kernel/auth stay in `~/.prime/agent/`. Telemetry off (`PRIME_AGENT_TELEMETRY=0`, `DO_NOT_TRACK=1`).
- Never exec host `pi` — wrapper requires basename `prime-agent`.
- Never exec `codex-titanium`. Titanium is reserved for sekhmet L3 workers. L2 is `prime-agent` only.

## Install

User-level official installer, pin **0.7.4**. Adapter is markdown + POSIX sh only; do not vendor `prime-agent`.
