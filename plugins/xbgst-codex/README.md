# xbgst for Codex

`xbgst-codex` ports the xbgst orchestration contract to the native Codex and ChatGPT plugin surface. It keeps the two load-bearing pieces of the stack together:

- `wwkd` supplies the data-walk-first plan and trusted end-to-end skeleton.
- `xbgst-shared` supplies role, evidence, lifecycle, and integration invariants.

The implementation path is always native Codex subagent delegation. Optional raw local `xask` calls are consultations: their output is evidence for the L1 judge, never authority to edit, approve, integrate, commit, push, publish, or spend beyond what the user authorized.

This default plugin registers no MCP server. If you want the visual, preview-first provider/model/effort console, install the separate opt-in `xbgst-delegation-ui` companion. The companion never becomes a prerequisite for native xbgst orchestration.

## Activate

Start a new Codex task after installing the plugin, then say one of:

```text
xbgst: implement this request
xbgst: review the current worktree
godspeed — use the xbgst stack
```

The orchestrator starts with a single planner, waits for its WWKD artifact, names measurable axes, and then runs at most six evidence-gated proposal rounds. Every proposal round has a connector. Concurrency is bounded by the active host ceiling (64 on this host), and all specialists remain directly owned by the L1 orchestrator.

## Authority boundary

Installing this plugin does not grant new authority. Codex host permissions, sandboxing, approval policy, repository instructions, and the user's request always win. The plugin never assumes permission to push, publish, deploy, delete, purchase provider usage, alter authentication, or rewrite Codex configuration.

## Package layout

| Path | Purpose |
|---|---|
| `.codex-plugin/plugin.json` | Universal plugin manifest |
| `skills/xbgst/SKILL.md` | Native Codex L1 judge and orchestration loop |
| `skills/xbgst/references/xbgst-shared.md` | Portable orchestration contract |
| `skills/xbgst/references/roles/` | Bounded specialist role cards |
| `skills/xbgst/references/godspeed-core/` | Judge-only Godspeed trilogy |
| `skills/wwkd/SKILL.md` | Byte-for-byte WWKD planning posture |

## Local validation

From the marketplace repository root:

```bash
bash scripts/smoke-xbgst-codex.sh
```

The smoke is read-only. It checks manifests, package paths, portable policy invariants, shell syntax, and byte identity for WWKD and the Godspeed trilogy. When the opt-in delegation UI companion is present, it validates that package and runs its offline stdio protocol test too.
