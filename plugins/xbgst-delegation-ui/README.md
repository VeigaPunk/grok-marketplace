# xbgst Delegation UI

This is the opt-in visual companion for `xbgst-codex`. The default xbgst plugin remains raw-local and MCP-free; installing this package adds a burnerchrome-style MCP App that talks to the `xask` executable already installed on your machine.

## What it exposes

- `xask_catalog` reads the live provider/model/effort registry and runtime availability.
- `xask_plan` validates a selection and returns literal argv without executing it.
- `xask_dispatch` is a separate mutating/open-world tool call that executes the validated route.

Every preview and dispatch preserves the canonical Godspeed contract: `--gs` explicitly loads `directive.md`, and the delegated task ends exactly once with the literal suffix `| godspeed`. Repeated terminal markers are normalized; `godspeed: false` is rejected. Godspeed is not shorthand for WWKD—WWKD remains the separate Phase 0 planning skill.

The bridge uses dependency-free Node.js 22+ and JSON-RPC over stdio. It invokes `xask` with an argv array and `shell: false`, caps runtime and captured output, accepts only catalog-backed selections, and never returns environment variables or provider credentials. An optional working directory must resolve to an existing absolute directory.

## Install

After adding the `veigapunk-xbgst` marketplace, install the companion explicitly:

```bash
codex plugin add xbgst-delegation-ui@veigapunk-xbgst --json
```

Requirements:

- Node.js 22 or newer available as `node`
- `xask` available on `PATH`
- provider authentication owned by the corresponding local CLI

Installing the companion does not dispatch anything. In the console, **Preview argv** is read-only; **Dispatch now** is a distinct action with a confirmation step.

## Offline validation

From this marketplace repository:

```bash
node --check plugins/xbgst-delegation-ui/mcp/server.mjs
node --test plugins/xbgst-delegation-ui/mcp/server.test.mjs
```

The protocol test uses a fake `xask` executable. It verifies initialization, tool/resource discovery, widget delivery, plan behavior, dispatch argv capture, working-directory validation, and resistance to shell metacharacter injection without contacting a provider.
