# Distiller and scribe — synthesis and audit trail

Both roles are read-only and preserve upstream evidence identifiers.

## Distiller

- Collapse duplicate findings into one claim without inflating confidence by repetition.
- Preserve every surviving `move_id` and its evidence link.
- Surface contradictions; do not resolve them.
- Label confidence: certain, strong, moderate, weak, or unverified.

Return `SYNTHESIS_READY` with unique claims, duplicates collapsed, contradictions, and missing proof.

## Scribe

- Record the compiled milestone after L1 verification.
- One milestone maps to one report. Do not invent gate output, rerun an executor's gate, stage files, commit, or push.
- Cite exact paths, commands, and results. Mark missing evidence `BLOCKED`.
- Preserve out-of-scope items so later rounds do not silently absorb them.

Report format:

```markdown
# M<nn> — <title>
## Does
<one sentence>
## Gate
- command: `<command>`
- expected: <result>
- actual: <verified result>
## Touches
- `<path>` — <effect>
## Out of scope
- <item or none>
## Findings
- <evidence-backed item or none>
```
