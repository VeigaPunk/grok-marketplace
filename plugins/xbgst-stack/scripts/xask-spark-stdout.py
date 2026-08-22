#!/usr/bin/env python3
"""Extract sekhmet --spark model text from a CollectRecord envelope on stdin.

CLI stdout of `xask --spark` is the envelope (spark_id, result_path, …),
not the model answer. The answer is result.json stdout under the spark root.

Does **not** open envelope result_path (operator-controlled). Derives
  <sekhmet default_root>/<spark_id>/out/result.json
after validating spark_id, then realpath-contains it.

default_root (xbrd-spark/src/lib.rs): $XBRD_SPARK_ROOT, else
$XDG_RUNTIME_DIR/xbrd-spark, else /tmp/xbrd-spark.
spark_id grammar matches sekhmet validate_spark_id: sp-[A-Za-z0-9_-]+, max 128.
"""
from __future__ import annotations

import json
import os
import re
import sys

# Remainder [A-Za-z0-9_-]+ ; full id length checked separately (≤128).
SPARK_ID_RE = re.compile(r"^sp-[A-Za-z0-9_-]+$")


def fail(code: int, msg: str) -> None:
    print(msg, file=sys.stderr)
    raise SystemExit(code)


def default_spark_parent() -> str:
    override = os.environ.get("XBRD_SPARK_ROOT") or ""
    if override:
        return os.path.realpath(override)
    xdg = os.environ.get("XDG_RUNTIME_DIR") or ""
    if xdg:
        return os.path.realpath(os.path.join(xdg, "xbrd-spark"))
    return os.path.realpath("/tmp/xbrd-spark")


def main() -> None:
    raw = sys.stdin.read()
    start = raw.find("{")
    if start < 0:
        fail(2, "xask-spark-stdout: no JSON object on stdin")
    try:
        env = json.loads(raw[start:])
    except json.JSONDecodeError as exc:
        fail(2, f"xask-spark-stdout: envelope JSON: {exc}")
    if not isinstance(env, dict):
        fail(2, "xask-spark-stdout: envelope is not an object")
    sid = env.get("spark_id")
    if (
        not isinstance(sid, str)
        or not SPARK_ID_RE.match(sid)
        or len(sid) > 128
        or ".." in sid
        or "/" in sid
        or "\\" in sid
    ):
        fail(3, "xask-spark-stdout: missing or invalid spark_id")
    parent = default_spark_parent()
    root = os.path.realpath(os.path.join(parent, sid))
    path = os.path.realpath(os.path.join(root, "out", "result.json"))
    if not path.startswith(root + os.sep):
        fail(4, "xask-spark-stdout: result path escapes spark root")
    try:
        with open(path, "r", encoding="utf-8") as fh:
            result = json.load(fh)
    except OSError as exc:
        fail(5, f"xask-spark-stdout: cannot read result.json: {exc}")
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        fail(5, f"xask-spark-stdout: result.json: {exc}")
    if not isinstance(result, dict):
        fail(5, "xask-spark-stdout: result.json is not an object")
    stdout = result.get("stdout")
    if not isinstance(stdout, str) or stdout == "":
        fail(6, "xask-spark-stdout: empty result.json stdout")
    sys.stdout.write(stdout)


if __name__ == "__main__":
    main()
