#!/usr/bin/env python3
"""Backfill agent-ledger event files into vaultwares-api."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
EVENTS_ROOT = ROOT / "events"
API_URL = (os.environ.get("VW_API_URL") or os.environ.get("VW_PIPELINES_URL") or "https://api.vaultwares.ca").rstrip("/")
API_KEY = os.environ.get("VW_TELEMETRY_API_KEY") or os.environ.get("VW_PIPELINES_API_KEY") or ""


def _load_events(since: str | None = None) -> list[dict]:
    events: list[dict] = []
    for path in sorted(EVENTS_ROOT.rglob("*.json")):
        if since and path.stem[:8] < since.replace("-", ""):
            continue
        try:
            event = json.loads(path.read_text(encoding="utf-8-sig"))
        except Exception as exc:
            print(f"skip {path}: {exc}", file=sys.stderr)
            continue
        if not isinstance(event, dict) or not event.get("id"):
            continue
        event["sourcePath"] = str(path.relative_to(ROOT))
        events.append(event)
    return events


def _post(events: list[dict]) -> dict:
    body = json.dumps({"events": events}, ensure_ascii=False, separators=(",", ":"), default=str).encode("utf-8")
    headers = {"Accept": "application/json", "Content-Type": "application/json", "User-Agent": "agent-ledger-import/1"}
    if API_KEY:
        headers["x-api-key"] = API_KEY
    request = Request(f"{API_URL}/api/ledger/agent/events/batches", data=body, headers=headers, method="POST")
    with urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--since", help="Import events on/after YYYY-MM-DD.")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    events = _load_events(args.since)
    print(f"parsed={len(events)} api={API_URL}")
    if args.dry_run:
        return 0
    if not events:
        return 0
    try:
        result = _post(events)
    except HTTPError as exc:
        print(f"api_error={exc.code} {exc.read().decode('utf-8', errors='replace')}", file=sys.stderr)
        return 1
    except URLError as exc:
        print(f"api_error={exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
