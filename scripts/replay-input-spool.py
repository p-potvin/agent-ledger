#!/usr/bin/env python3
"""Replay input tracker JSONL spool files into vaultwares-pipelines."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from urllib.error import URLError
from urllib.request import Request, urlopen

ROOT_DIR = Path(__file__).parent.resolve().parent
SPOOL_DIR = Path(os.environ.get("VW_INPUT_SPOOL_DIR") or (ROOT_DIR / "input-spool"))
PIPELINES_URL = os.environ.get("VW_PIPELINES_URL", "http://127.0.0.1:9001").rstrip("/")
API_KEY = os.environ.get("VW_PIPELINES_API_KEY") or os.environ.get("VW_TELEMETRY_API_KEY") or ""


def post_batch(batch: dict) -> None:
    headers = {"Content-Type": "application/json", "User-Agent": "agent-ledger-input-spool-replay/1"}
    if API_KEY:
        headers["x-api-key"] = API_KEY
    body = json.dumps(batch, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    request = Request(f"{PIPELINES_URL}/api/telemetry/input/batches", data=body, headers=headers, method="POST")
    with urlopen(request, timeout=10) as response:
        if response.status >= 300:
            raise URLError(f"status {response.status}")


def replay_file(path: Path) -> tuple[int, int]:
    sent = 0
    failed = 0
    remaining: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            post_batch(json.loads(line))
            sent += 1
        except Exception:
            failed += 1
            remaining.append(line)
    if remaining:
        path.write_text("\n".join(remaining) + "\n", encoding="utf-8")
    else:
        path.replace(path.with_suffix(path.suffix + ".sent"))
    return sent, failed


def main() -> int:
    if not SPOOL_DIR.exists():
        print("No spool directory.")
        return 0
    total_sent = 0
    total_failed = 0
    for path in sorted(SPOOL_DIR.glob("*.jsonl")):
        sent, failed = replay_file(path)
        total_sent += sent
        total_failed += failed
        print(f"{path.name}: sent={sent} failed={failed}")
    print(f"total_sent={total_sent} total_failed={total_failed}")
    return 1 if total_failed else 0


if __name__ == "__main__":
    sys.exit(main())
