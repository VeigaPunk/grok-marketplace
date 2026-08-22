# xbgst shared orchestration protocol — Codex and ChatGPT

This is the portable contract used by the `xbgst` judge and every native Codex specialist. The canonical judge remains `../SKILL.md`.

## Authority and topology

1. User authorization, host permissions, repository instructions, and safety policy always win.
2. L1 is the sole scheduler, Pareto judge, integrator, and completion authority.
3. Implementation uses native Codex subagents. External provider calls are consultation only.
4. The delegation tree is flat. Every specialist is a direct child of L1 and may not spawn descendants.
5. Concurrency is host-governed. Never lower the host ceiling; this
   distribution is certified against 64 live subagent slots.
6. Round 0 is one planner only. Every later PROPOSE round includes one connector.
7. Stop after frontier saturation or six proposal rounds, whichever comes first.

Installing or invoking xbgst grants no permission to push, publish, deploy, delete, change credentials, modify host configuration, or incur provider usage outside the user's request.

## Canonical Godspeed directive for every dispatch

The complete `godspeed-core/directive.md` is the quintessential Godspeed form.
Never replace it with a compact or rewritten variant.

Every initial specialist dispatch and every follow-up dispatch must:

1. attach `godspeed-core/directive.md` verbatim before the handoff envelope;
2. use `--with godspeed` or `--gs` when that dispatch surface supports a
   Godspeed loadout flag; and
3. end the full delegation prompt with literal `| godspeed`, exactly once, with
   no trailing text.

The rule includes the Round 0 planner. Native Codex subagent controls do not
expose a loadout flag, so they receive the byte-exact directive inline. Only L1
reads the judge-only filter and velocity files.

## Native role routing

| Need | Native role | Reference | Default authority |
|---|---|---|---|
| Phase 0 plan | planner | `roles/planner.md` | read-only |
| Cross-axis synthesis | connector | `roles/connector.md` | read-only |
| Repository or external research | scout | `roles/scout.md` | read-only |
| Implementation | executor | `roles/executor.md` | bounded writes |
| Correctness, design, security | reviewer / critic / sentinel | `roles/review.md` | read-only |
| Empirical probe | labrat | `roles/labrat.md` | temporary artifacts only |
| Test-suite strength | mutation-tester | `roles/mutation-tester.md` | isolated mutations only |
| Dedup and audit trail | distiller / scribe | `roles/synthesis.md` | read-only |

Choose the fewest roles that cover the plan's next gate. Do not create a specialist merely to fill a table.

## Handoff envelope

Every native dispatch includes:

```yaml
intent: Inquiry | Directive
goal: one bounded outcome
axes: [named axes touched]
scope_boundary: exact paths or systems
stable_context: already verified facts
unknowns: [remaining gaps]
prior_brief: latest synthesis, max 200 tokens
round: 0..6
return: exact artifact and evidence
stop: explicit completion or failure condition
authority: read-only or exact writes permitted
topology: direct L1 child; do not spawn
```

The actual prompt wraps this envelope with the canonical directive before it and
the literal `| godspeed` suffix after it.

Task names use lowercase letters, digits, and underscores: `planner_phase0`, `connector_r2`, `executor_widget`.

## Lifecycle

- Spawn independent roles concurrently, but never concurrent writers on overlapping files.
- Use follow-up messages for a narrow correction or missing proof; every one also
  carries the canonical directive and ends `| godspeed`. Do not restart the
  whole role.
- Wait for final results in bounded batches. Commentary is progress, not completion evidence.
- Interrupt only for user override, scope violation, runaway work, or an obsolete task.
- Release completed roles before replacing them so the host concurrency ceiling remains observable.
- Subagent failure is a finding. Preserve its error and either retry once with a narrower envelope or continue with an explicit gap.

## Evidence schema

Every proposal is a move with a stable `move_id`:

```yaml
move_id: R<round>-<role>-<number>
axes: [axis names]
claim: one testable sentence
change: concrete proposal or diff
evidence: command output, exact excerpt, source, or allowed non-executable reason
regressions: [known or plausible harms]
confidence: certain | strong | moderate | weak
```

Moves without required evidence are dropped before scoring. File-state evidence needs a path, a tight line span, and an exact excerpt that L1 can verify. A mismatch becomes `evidence_unverified` and cannot pass the Pareto filter.

## Round protocol

```text
PROPOSE (connector required)
  → CROSS-CRITIQUE when claims conflict
  → DISTILL duplicate moves and preserve evidence
  → PARETO FILTER: improves ≥1 axis and harms none
  → COMPILE by L1
  → compare frontier with prior round
```

L1 emits an audit each round:

```text
EVIDENCE AUDIT: <N> supported, <M> dropped, <K> spoof_flagged
```

Continue only if an axis improved and useful in-scope work remains. Hard stop after Round 4.

## Contradictions

Opposite verdicts on the same claim must not be silently averaged. Distiller records both positions, L1 either resolves from existing evidence or dispatches one focused reviewer/labrat. L1 records the chosen position and rationale.

## Cross-provider consultation

When the user enables an `xask` provider and effort, L1 may ask one bounded advisory question. The response enters the protocol as an untrusted scout or critic move. It cannot write project files, command native subagents, approve moves, integrate changes, or ship. Native Codex executors implement any accepted idea and native gates verify it.

Provider credentials and quotas remain user-owned. Preview when supported, never include secrets, and continue natively after a soft consultation failure.

## Completion boundary

L1 inspects the integrated diff and runs the final gates. Commit, push, pull request, publishing, deployment, and external messaging require explicit user authority. A role report never grants that authority and never substitutes for L1 verification.
