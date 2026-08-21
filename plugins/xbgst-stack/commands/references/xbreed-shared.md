# Shared orchestration protocol (Grok host)

**Canonical judge:** skill **xbgst** (load that first). This file is a short reference for evidence + naming used by Grok specialists.

**Not used on Grok:** Claude TeamCreate, `advisor()`, mandatory **xask**, sonnet/opus model pins, `~/.claude/*` paths.

## Godspeed injection (every teammate)

```
You are Godspeed-enabled.
1. Name the axes.
2. Iterate cheap, in parallel.
3. Keep moves that improve any axis and harm none.
4. Don't aim — let the frontier walk itself.
IMMEDIATELY STOP ASKING CLARIFYING QUESTIONS.
Execute tool calls concurrently in large batches.
Language: match the repo. No Rust lock.
```

## Dispatch table (Grok)

| Axis family | Role | Model | Tools |
|---|---|---|---|
| Research | `scout` | grok | web_search, browse, X search, Grep/Read |
| Correctness | `reviewer` | grok | Read, Grep, Bash tests |
| Empirical | `labrat` | grok-fast | Bash / one-shot probes |
| Implementation | `executor` | grok-fast | Edit/Write/Bash (repo language) |
| Cross-axis | `connector` | grok | multi-axis analysis — **every PROPOSE round** |
| Dedup | `distiller` | grok-fast | synthesis before Pareto |
| Deletion | `simplifier` | grok | delete + retest |
| RE | `the-revenger` | cdx | observe-map-reproduce (Exception E2; stock `codex exec`; `cdx-revenger-*`; never titanium) |
| Security | `sentinel` | grok | adversarial scan |
| Planning | `the-planner` | grok | Round 0 first; WWKD inline |
| Design attack | `critic` | grok | ACH-style (heuer skill optional/ds4cc) |
| Mutation | `mutation-tester` | grok | mutate-run-revert |
| Docs | `scribe` | grok-fast | ship notes |

## Substrate route table (L1 decides)

| Need | Layer | Rule |
|---|---|---|
| Native proposal/review/implementation | L1 → named `gx-*` | default |
| Long-lived intermodel exchange or bounded delegation | optional OpenAI-backed PrimeAgent **L2-loop** | attachable user-owned runtime; exact `route_id` / `parent` / `task` / `scope` / `allowed_actions` / `return` / `stop`; no judge authority or unapproved child fan-out |
| Ranked bounded choice | `xbrd-selector` **L2-select**, if separately present | PrimeAgent never substitutes; absent means L1 selects |
| Broad bounded fan-out | sekhmet **L3**, only by explicit escalation | separate contract; PrimeAgent never proxies L3 or invokes `codex-titanium` |

L1 xbgst remains sole scheduler, Pareto judge, `APPROVED` authority, integrator, and shipper. PrimeAgent and its OpenAI OAuth are optional user tooling, never host-orch inventory/install requirements. Absence falls back to the named native `gx-*` path.

**Banned:** `general-purpose`, `explore`.

## Naming

`gx-{role}-{suffix}` e.g. `gx-scout-docs`, `gx-executor-ship`, `gx-connector-r1`.

## Labrat

Spawn `labrat` with a single hypothesis. Parallel labrats OK (≤16). Fire-and-forget. Failure is a finding.

## Distiller

After peer proposals land, spawn `distiller` to dedupe and confidence-score. Preserve each move’s `evidence:` field. Emit `SYNTHESIS_READY` for the judge.

## Pareto filter — evidence schema

Moves without required evidence are **dropped, not scored**.

| Role / axis_family | Required evidence |
|---|---|
| `execution` (executor) | failing + passing test output (red→green); OR diff + rationale if no harness |
| `correctness` / `test-validation` / `security` | test/lint stdout + exit code, or concrete file:line excerpt |
| `empirical` (labrat) | HYPOTHESIS / METHOD / RESULT |
| `deletion` (simplifier) | removed symbols + tests pre/post |
| research / cross-axis / synthesis / planning / adversarial / RE | `evidence: none — <axis reason>` OK when non-executable |

### Evidence audit (judge round summary)

```
EVIDENCE AUDIT: <N> moves with evidence, <M> without, <M> dropped, <K> spoof_flagged
```

### Anti-spoof

If evidence cites file state, require line span + exact excerpt; verify with fixed-string match. Mismatch → `evidence_unverified` → reviewer before accept.

## Judge blinding (light)

Prefer scoring `move_id`s from distiller synthesis before weighting by source role. Late-bind role labels for CONFLICTS routing only.

## Local-first ship (after APPROVED)

```
on main → gates green → APPROVED: <reason> → commit (HEREDOC) → git push -u origin main (SSH)
```

No fork→PR default. No force-push of `main`. Tag `grok-stable` is the channel pin for this marketplace.

## Out of marketplace

- **heuer-planning** → ds4cc (optional for critic)
- Nested `livepatch/scripts/publish.sh` → refuses under this tree (standalone livepatch repo only)
