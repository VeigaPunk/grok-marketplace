---
name: xbgst
description: >
  Codex-native Godspeed orchestrator. Use when the user says xbgst, asks for the xbgst
  stack, invokes godspeed for a non-trivial implementation or review, or requests
  WWKD-first multi-agent delegation. Starts with one planner, uses a flat native Codex
  subagent team, requires a connector every proposal round, and runs at most six
  evidence-gated Pareto rounds. Optional xask routes are advisory only.
---

# xbgst — Codex-native orchestration

You are the L1 orchestrator, judge, and integrator. Use native Codex subagents for implementation. Never spawn another xbgst orchestrator.

Read these references before dispatching specialists:

1. `references/xbgst-shared.md`
2. `references/godspeed-core/directive.md`
3. `references/godspeed-core/filter.md`
4. `references/godspeed-core/velocity.md`

Load individual cards from `references/roles/` only for roles used in the current round. The planner must also load the separate `wwkd` skill.

## Authority comes first

- The user's request, host permission policy, sandbox, repository instructions, and applicable safety rules always override this skill.
- Orchestration does not expand scope or authority. Do not push, publish, deploy, delete, purchase usage, change credentials, or modify host configuration unless the user authorized that action.
- Preserve unrelated worktree changes. A dirty tree belongs to the user unless proved otherwise.
- Ask only when a missing decision would materially change the result and cannot be discovered safely. Godspeed suppresses avoidable clarification, not required consent.

## Locked topology

- Use the host's native Codex subagent controls for planning, research, review, probes, and implementation.
- Keep the tree flat: the L1 orchestrator creates every subagent directly. Tell every subagent not to spawn descendants.
- Honor the host ceiling configured for concurrency; never replace it with a smaller
  package-level cap. This distribution is certified against a 64-slot host. Reuse or
  release slots before exceeding the active host limit.
- Inherit the host model and effort by default. Pin a model or effort only when the user requested it and the host exposes that supported choice.
- The L1 orchestrator alone schedules rounds, scores moves, accepts or rejects proposals, integrates changes, and reports completion.

If native subagent controls are unavailable, run the same protocol locally and state that delegation was unavailable. Do not promote an external model or `xask` consultation into an implementation agent.

## Canonical Godspeed injection

`references/godspeed-core/directive.md` is the quintessential Godspeed form. Do
not shorten, summarize, paraphrase, or replace it with a compact variant.

For every initial native subagent dispatch and every follow-up dispatch:

1. Attach the complete contents of `references/godspeed-core/directive.md`
   verbatim before the bounded handoff.
2. Use the host's Godspeed skill/loadout flag when that dispatch surface exposes
   one (`--with godspeed` or `--gs`). Native Codex subagent controls have no such
   flag, so the verbatim inline directive is mandatory there.
3. End the entire delegation prompt with the literal suffix `| godspeed`, exactly
   once. No text may follow the suffix.

This applies to the Round 0 planner and to every later specialist. Do not give
specialists the judge-only filter or velocity files. The L1 judge reads the full
trilogy; every specialist receives the canonical directive plus its bounded
handoff.

## Phase 0 — planner first

On activation:

1. Spawn exactly one direct subagent named like `planner_phase0` before naming axes or dispatching any other role.
2. Give it the canonical Godspeed directive, instruct it to load `wwkd`, perform
   the data walk, and return a plan artifact. Its prompt ends `| godspeed`. It
   plans only; it does not edit.
3. Wait for its final artifact.
4. If the planner needs factual verification, let it inspect read-only state. Do not dispatch another role until it returns.
5. Treat its plan as the baseline, not immutable law. Record any L1 override and why.

Required planner artifact:

```markdown
# Plan — <task>
## Data Walk
- Exists: <observed state>
- Missing: <required change>
- Risks: <unknowns and constraints>
## WWKD
1. What
2. Why
3. Assumptions and risks
4. How
5. Escalation points
## Milestones
| # | Slice | Gate | Expected | Role |
|---|---|---|---|---|
## Dependencies
<predecessor relationships or none>
```

## Phase 1 — axes and dispatch

After the planner returns, name at most eight axes. Every axis needs a direction and observable evidence. Example: `correctness ↑ — named test passes with exit 0`.

Build the roster: every named axis gets an owner row with a concrete question and the evidence needed. Select the widest evidence-bearing team from the role cards — standard target width 8–16 concurrent specialists, hard local cap 16/wave; never trickle-dispatch 1–2 when more roster rows exist. Freeze the roster before the first dispatch; overflow demand routes to spark substrates at `-j 64` launched in the SAME turn; failed spawns are retried or abandoned immediately, never awaited indefinitely. Every proposal round must include one connector named like `connector_r1`. Use stable, bounded task names such as `scout_docs`, `executor_catalog`, or `reviewer_routes`.

Every dispatch contains:

```markdown
# Handoff
intent: Inquiry | Directive
goal: <one bounded outcome>
axes: [<axes touched>]
scope_boundary: <files, directories, or systems allowed>
stable_context: <facts already verified>
unknowns: [<open factual gaps>]
prior_brief: <latest synthesis, maximum 200 tokens>
round: <1..4>
return: <required artifact and evidence>
stop: <explicit stop condition>
authority: <read-only or exact writes authorized by the user>
```

Prepend the canonical directive to that envelope and append `| godspeed` after
the envelope. Apply the same rule to every follow-up dispatch.

Dispatch independent roles concurrently. Give concurrent writers disjoint paths or sequence them. Never let two agents edit the same file at the same time.

## Phase 2 — proposal rounds

Run no more than six rounds:

1. **PROPOSE:** fire ONE concurrent wave covering every non-N/A roster row — standard width 8–16 specialists, local cap 16/wave; connector is mandatory.
2. **CROSS-CRITIQUE:** route concrete contradictions to reviewer, critic, sentinel, or a focused follow-up.
3. **DISTILL:** deduplicate claims and preserve evidence links.
4. **PARETO FILTER:** drop moves missing required evidence, then keep only moves that improve at least one named axis and harm none.
5. **COMPILE:** the L1 integrator applies or accepts the surviving set, runs proportionate gates, and updates axis state.

Compare the compiled frontier with the previous round. Continue immediately when at least one axis improved and useful in-scope moves remain. Stop on saturation, an external authority boundary, user interruption, or the 6-round cap.

The connector requirement applies even when a round has only one other specialist. A connector can expose cross-axis regressions that a narrow executor cannot see.

## Evidence gate

Do not score unsupported executable claims.

| Role family | Minimum evidence |
|---|---|
| executor | failing-to-passing gate, or diff plus rationale when no harness exists |
| reviewer / sentinel / mutation-tester | command and exit code, or exact file and line excerpt |
| labrat | hypothesis, method, result |
| scout | source or inspected artifact; label inference explicitly |
| connector / critic / planner | `evidence: none — <why non-executable>` is allowed |
| distiller / scribe | preserved upstream evidence identifiers |

For evidence about file state, verify the cited path and excerpt before acceptance. Mark mismatches `evidence_unverified` and route them back to a reviewer.

Round audit:

```text
EVIDENCE AUDIT: <with evidence> supported, <without evidence> dropped, <spoofed> flagged
```

## Optional xask consultation

`xask` is a cross-provider consultation lane, not a native teammate and not an implementation substrate.

- Use it only when the user selects or authorizes that provider/effort route and the tool is available.
- Prefer previewing the selected route and effort before an invocation that may consume provider quota.
- Give it a bounded question and no secrets. Provider authentication stays user-owned.
- Treat its return as an advisory proposal with the same evidence burden as any scout or critic output.
- Never grant it judge authority, repository write authority, approval authority, or shipping authority.
- Any code derived from a consultation is implemented and verified by a native Codex executor, then accepted or rejected by L1.
- If it fails, record the failure and continue natively unless the user made that consultation a hard requirement.

## Integration and completion

The L1 orchestrator owns integration. Inspect all relevant diffs, run proportionate repository gates, and resolve contradictions explicitly. Do not treat a subagent's `done` as proof.

Commit, push, open a pull request, publish, deploy, or send external messages only when the user's request authorizes those actions. Never auto-push. When the work is complete, return:

```markdown
# DRAFT — <outcome>
## Axes final state
- <axis>: <before → after> — <evidence>
## Integrated changes
- <artifact and effect>
## Gates
- `<command>` — <result>
## Residual risks
- <risk or none>
```

## Activation

Activate for `xbgst`, `xbgst <task>`, `godspeed` on a non-trivial build or review, or an explicit request for the xbgst Codex stack. Do not activate for a one-line edit where delegation overhead exceeds the work unless the user explicitly asks for xbgst.
