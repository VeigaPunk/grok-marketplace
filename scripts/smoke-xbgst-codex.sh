#!/usr/bin/env bash
set -euo pipefail

XBGST_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
XBGST_PLUGIN_ROOT="$XBGST_REPO_ROOT/plugins/xbgst-codex"
XBGST_UI_PLUGIN_ROOT="$XBGST_REPO_ROOT/plugins/xbgst-delegation-ui"
XBGST_GROK_ROOT="$XBGST_REPO_ROOT/plugins/xbgst-stack"

fail() {
  printf 'xbgst-codex structural smoke: FAIL: %s\n' "$*" >&2
  exit 1
}

for XBGST_REQUIRED_FILE in \
  "$XBGST_REPO_ROOT/.agents/plugins/marketplace.json" \
  "$XBGST_PLUGIN_ROOT/.codex-plugin/plugin.json" \
  "$XBGST_PLUGIN_ROOT/README.md" \
  "$XBGST_PLUGIN_ROOT/skills/xbgst/SKILL.md" \
  "$XBGST_PLUGIN_ROOT/skills/xbgst/references/xbgst-shared.md" \
  "$XBGST_PLUGIN_ROOT/skills/wwkd/SKILL.md"; do
  [[ -f "$XBGST_REQUIRED_FILE" ]] || fail "missing ${XBGST_REQUIRED_FILE#$XBGST_REPO_ROOT/}"
done

[[ ! -e "$XBGST_PLUGIN_ROOT/.mcp.json" ]] \
  || fail "default xbgst-codex plugin must remain MCP-free"

python3 -m json.tool "$XBGST_REPO_ROOT/.agents/plugins/marketplace.json" >/dev/null
python3 -m json.tool "$XBGST_PLUGIN_ROOT/.codex-plugin/plugin.json" >/dev/null
bash -n "$XBGST_REPO_ROOT/scripts/install-xbgst-codex.sh"
bash -n "$XBGST_REPO_ROOT/scripts/smoke-xbgst-codex.sh"

if [[ -d "$XBGST_UI_PLUGIN_ROOT" ]]; then
  for XBGST_UI_REQUIRED_FILE in \
    "$XBGST_UI_PLUGIN_ROOT/.codex-plugin/plugin.json" \
    "$XBGST_UI_PLUGIN_ROOT/.mcp.json" \
    "$XBGST_UI_PLUGIN_ROOT/README.md" \
    "$XBGST_UI_PLUGIN_ROOT/mcp/server.mjs" \
    "$XBGST_UI_PLUGIN_ROOT/mcp/server.test.mjs" \
    "$XBGST_UI_PLUGIN_ROOT/mcp/test/fixtures/fake-xask.mjs" \
    "$XBGST_UI_PLUGIN_ROOT/ui/delegation.html"; do
    [[ -f "$XBGST_UI_REQUIRED_FILE" ]] \
      || fail "missing ${XBGST_UI_REQUIRED_FILE#$XBGST_REPO_ROOT/}"
  done
  command -v node >/dev/null 2>&1 || fail "Node.js is required to validate xbgst-delegation-ui"
  python3 -m json.tool "$XBGST_UI_PLUGIN_ROOT/.codex-plugin/plugin.json" >/dev/null
  python3 -m json.tool "$XBGST_UI_PLUGIN_ROOT/.mcp.json" >/dev/null
  node --check "$XBGST_UI_PLUGIN_ROOT/mcp/server.mjs"
  node --test "$XBGST_UI_PLUGIN_ROOT/mcp/server.test.mjs"
fi

python3 - "$XBGST_REPO_ROOT" <<'PY'
import hashlib
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
market = json.loads((root / ".agents/plugins/marketplace.json").read_text())
assert market["name"] == "veigapunk-xbgst"
assert market.get("interface", {}).get("displayName")
entries = [item for item in market["plugins"] if item.get("name") == "xbgst-codex"]
assert len(entries) == 1
assert market["plugins"][0].get("name") == "xbgst-codex"
entry = entries[0]
assert entry["source"] == {"source": "local", "path": "./plugins/xbgst-codex"}
assert entry["policy"] == {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}
assert entry.get("category")

plugin_root = root / "plugins/xbgst-codex"
manifest = json.loads((plugin_root / ".codex-plugin/plugin.json").read_text())
assert manifest["name"] == "xbgst-codex"
assert manifest["skills"] == "./skills/"
assert "mcpServers" not in manifest
assert manifest.get("interface", {}).get("defaultPrompt")

ui_root = root / "plugins/xbgst-delegation-ui"
if ui_root.is_dir():
    ui_entries = [item for item in market["plugins"] if item.get("name") == "xbgst-delegation-ui"]
    assert len(ui_entries) == 1
    ui_entry = ui_entries[0]
    assert ui_entry["source"] == {"source": "local", "path": "./plugins/xbgst-delegation-ui"}
    assert ui_entry["policy"] == {"installation": "AVAILABLE", "authentication": "ON_USE"}
    assert ui_entry.get("category") == "Developer Tools"

    ui_manifest = json.loads((ui_root / ".codex-plugin/plugin.json").read_text())
    assert ui_manifest["name"] == "xbgst-delegation-ui"
    assert ui_manifest["mcpServers"] == "./.mcp.json"
    assert "skills" not in ui_manifest

    mcp = json.loads((ui_root / ".mcp.json").read_text())
    servers = mcp.get("mcpServers", {})
    assert list(servers) == ["xbgst-delegation"]
    server = servers["xbgst-delegation"]
    assert server["cwd"] == "."
    assert server["command"] == "node"
    assert server["args"] == ["./mcp/server.mjs"]
    assert {"HOME", "PATH"} <= set(server["env_vars"])

required_roles = {
    "planner.md", "connector.md", "scout.md", "executor.md",
    "review.md", "labrat.md", "mutation-tester.md", "synthesis.md",
}
roles = plugin_root / "skills/xbgst/references/roles"
assert required_roles <= {path.name for path in roles.iterdir() if path.is_file()}

skill = (plugin_root / "skills/xbgst/SKILL.md").read_text()
shared = (plugin_root / "skills/xbgst/references/xbgst-shared.md").read_text()
for needle in (
    "planner first", "host", "ceiling", "64", "connector", "six rounds",
    "native Codex subagents", "advisory", "Never auto-push",
):
    assert needle.lower() in skill.lower(), needle
for needle in ("flat", "host", "ceiling", "64", "connector", "six proposal rounds", "consultation only"):
    assert needle.lower() in shared.lower(), needle

expected_godspeed = (
    "You are a Godspeed-enabled subagent.\n"
    "\n"
    "1. **Name the axes.**\n"
    "2. **Iterate cheap, in parallel.**\n"
    "3. **Keep moves that improve any axis and harm none.**\n"
    "4. **Don't aim — let the frontier walk itself.**\n"
    "\n"
    "## IMMEDIATELY STOP ASKING CLARIFYING QUESTIONS. Execute tool calls concurrently in large batches. "
    "Do not serialize what can run in parallel. Do not output philosophical reasoning or verbose plans. "
    "Act directly via tool calls.\n"
).encode()
expected_godspeed_sha256 = "db88963cbdf5a0db22b460b284bf6f1d1f4abac9eaadb28bdb5e9bffe27be3bb"
assert hashlib.sha256(expected_godspeed).hexdigest() == expected_godspeed_sha256
for directive in (
    root / "plugins/xbgst-stack/ssot/godspeed-core/directive.md",
    plugin_root / "skills/xbgst/references/godspeed-core/directive.md",
):
    payload = directive.read_bytes()
    digest = hashlib.sha256(payload).hexdigest()
    assert digest == expected_godspeed_sha256, f"non-canonical Godspeed hash in {directive}: {digest}"
    assert payload == expected_godspeed, f"non-canonical Godspeed directive in {directive}"

# Reject package-imposed 8/16 worker ceilings without treating a role inventory or
# a suggested local batch size as a global concurrency cap.
cap_patterns = tuple(
    re.compile(pattern, re.IGNORECASE)
    for pattern in (
        r"\bmax[_-](?:concurrent|threads?|workers?|subagents?|agents?)[a-z0-9_-]*\s*[:=]\s*[\"']?(?:8|16)\b",
        r"\b(?:concurrency|parallelism)[_-]?(?:max(?:imum)?|limit|cap)?\s*[:=]\s*[\"']?(?:8|16)\b",
        r"\b(?:maximum|max|limit|cap|ceiling)\s+(?:concurrent\s+)?(?:threads?|workers?|subagents?|agents?|delegations?)\s*(?:is|of|to|at|=|:)?\s*(?:8|16)\b",
        r"\b(?:maximum|max|limit|cap|ceiling)\s*(?:of\s+)?(?:8|16)\s+(?:concurrent\s+)?(?:threads?|workers?|subagents?|agents?|delegations?)\b",
        r"\b(?:threads?|workers?|subagents?|agents?|delegations?)\s+(?:maximum|max|limit|cap|ceiling)\s*(?:is|of|to|at|=|:)?\s*(?:8|16)\b",
        r"\b(?:concurrency|parallelism)\s+(?:maximum|max|limit|cap|ceiling)\s*(?:is|of|to|at|=|:)?\s*(?:8|16)\b",
        r"\b(?:8|16)[-\s]+(?:concurrent\s+)?(?:threads?|workers?|subagents?|agents?|delegations?)[-\s]+(?:maximum|max|limit|cap|ceiling)\b",
        r"\b(?:threads?|workers?|subagents?|agents?|delegations?|concurrency|parallelism)\s+(?:is\s+)?(?:capped|limited)\s+(?:to|at)\s+(?:8|16)\b",
        r"\b(?:up\s+to|no\s+more\s+than|at\s+most)\s+(?:8|16)\s+(?:concurrent\s+)?(?:threads?|workers?|subagents?|agents?|delegations?)\b",
    )
)
for cap_example in (
    "max_concurrent_threads_per_session = 8",
    "up to 16 concurrent subagents",
    "workers capped at 8",
    "16 workers max",
):
    assert any(pattern.search(cap_example) for pattern in cap_patterns), cap_example
for allowed_example in (
    "16 named role definitions",
    "16 subagents total",
    "Run 4-8 in parallel.",
    "16 roles; the concurrency ceiling remains host-governed at 64.",
):
    assert not any(pattern.search(allowed_example) for pattern in cap_patterns), allowed_example
text_suffixes = {".css", ".html", ".js", ".json", ".md", ".mjs", ".sh", ".toml", ".yaml", ".yml"}
scan_roots = [plugin_root, root / "plugins/xbgst-delegation-ui"]
scan_files = [
    root / ".agents/plugins/marketplace.json",
    root / "scripts/install-xbgst-codex.sh",
]
for scan_root in scan_roots:
    if scan_root.is_dir():
        scan_files.extend(
            path for path in scan_root.rglob("*")
            if path.is_file() and path.suffix.lower() in text_suffixes
        )
for path in scan_files:
    text = path.read_text(errors="replace")
    for line_number, line in enumerate(text.splitlines(), 1):
        if any(pattern.search(line) for pattern in cap_patterns):
            relative = path.relative_to(root)
            raise AssertionError(f"package-level 8/16 concurrency cap in {relative}:{line_number}: {line.strip()}")
PY

cmp -s \
  "$XBGST_GROK_ROOT/skills/wwkd/SKILL.md" \
  "$XBGST_PLUGIN_ROOT/skills/wwkd/SKILL.md" \
  || fail "Codex WWKD copy drifted from the Grok package"

for XBGST_GODSPEED_FILE in directive.md filter.md velocity.md; do
  cmp -s \
    "$XBGST_GROK_ROOT/ssot/godspeed-core/$XBGST_GODSPEED_FILE" \
    "$XBGST_PLUGIN_ROOT/skills/xbgst/references/godspeed-core/$XBGST_GODSPEED_FILE" \
    || fail "Godspeed $XBGST_GODSPEED_FILE copy drifted from the Grok package"
done

if command -v rg >/dev/null 2>&1; then
  if rg -n 'git push -u origin main|~/.grok|grok-4|livepatch|spawn_subagent|TeamCreate' \
    "$XBGST_PLUGIN_ROOT/skills/xbgst/SKILL.md" \
    "$XBGST_PLUGIN_ROOT/skills/xbgst/references/xbgst-shared.md" \
    "$XBGST_PLUGIN_ROOT/skills/xbgst/references/roles"; then
    fail "Grok-only or auto-push behavior leaked into the Codex orchestration contract"
  fi
  if rg -n -F '[TODO:' "$XBGST_PLUGIN_ROOT"; then
    fail "placeholder remains in the Codex plugin"
  fi
  if [[ -d "$XBGST_UI_PLUGIN_ROOT" ]] && rg -n -F '[TODO:' "$XBGST_UI_PLUGIN_ROOT"; then
    fail "placeholder remains in the delegation UI plugin"
  fi
fi

if [[ -n "${XBGST_PLUGIN_VALIDATOR:-}" ]]; then
  python3 "$XBGST_PLUGIN_VALIDATOR" "$XBGST_PLUGIN_ROOT"
  if [[ -d "$XBGST_UI_PLUGIN_ROOT" ]]; then
    python3 "$XBGST_PLUGIN_VALIDATOR" "$XBGST_UI_PLUGIN_ROOT"
  fi
fi

printf 'xbgst-codex structural smoke: PASS\n'
