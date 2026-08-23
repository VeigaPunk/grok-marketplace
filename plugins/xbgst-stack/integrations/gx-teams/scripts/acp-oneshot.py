#!/usr/bin/env python3
"""Minimal ACP one-shot: initialize then kill. Flags before stdio."""
from __future__ import annotations

import json
import os
import subprocess
import sys


def main() -> int:
    env = os.environ.copy()
    env["GROK_SUBAGENTS"] = "0"
    proc = subprocess.Popen(
        ["grok", "agent", "--no-leader", "--always-approve", "stdio"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
        bufsize=1,
    )
    assert proc.stdin is not None and proc.stdout is not None
    req = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": 1,
            "clientCapabilities": {
                "fs": {"readTextFile": True, "writeTextFile": True},
                "terminal": True,
            },
        },
    }
    try:
        proc.stdin.write(json.dumps(req) + "\n")
        proc.stdin.flush()
        line = proc.stdout.readline()
        if not line:
            err = proc.stderr.read() if proc.stderr else ""
            print(f"no stdout from grok agent stdio: {err}", file=sys.stderr)
            return 1
        msg = json.loads(line)
        result = msg.get("result") or {}
        pv = result.get("protocolVersion")
        if pv is None:
            print(f"missing protocolVersion in result: {msg}", file=sys.stderr)
            return 1
        print(f"protocolVersion={pv}")
        return 0
    finally:
        try:
            proc.stdin.close()
        except Exception:
            pass
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=2)


if __name__ == "__main__":
    raise SystemExit(main())
