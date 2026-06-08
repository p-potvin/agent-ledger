#!/usr/bin/env python3
"""Import legacy input-logs JSON files into the VaultWares API telemetry endpoint."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import socket
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT_DIR = Path(__file__).resolve().parent.parent
INPUT_LOG_DIR = ROOT_DIR / "input-logs"
API_URL = (os.environ.get("VW_API_URL") or os.environ.get("VW_PIPELINES_URL") or "http://127.0.0.1:9001").rstrip("/")
API_KEY = os.environ.get("VW_TELEMETRY_API_KEY") or os.environ.get("VW_PIPELINES_API_KEY") or ""
SOURCE = "agent-ledger-input-log-import"


def _hash(payload: Any) -> str:
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), default=str).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _iso_hour(day: str, hour: int) -> tuple[str, str]:
    start = datetime.fromisoformat(f"{day}T{hour:02d}:00:00+00:00")
    end_hour = hour + 1
    if end_hour == 24:
        end = datetime.fromisoformat(f"{day}T23:59:59+00:00")
    else:
        end = datetime.fromisoformat(f"{day}T{end_hour:02d}:00:00+00:00")
    return start.isoformat().replace("+00:00", "Z"), end.isoformat().replace("+00:00", "Z")


def _num(row: dict[str, Any], key: str) -> float:
    try:
        return float(row.get(key, 0) or 0)
    except Exception:
        return 0.0


def _has_activity(row: dict[str, Any]) -> bool:
    return any(
        _num(row, key) > 0
        for key in ("keystrokes", "chars_typed", "mouse_distance_m", "saves", "copies", "pastes", "chars_pasted")
    )


def _event(day: str, row: dict[str, Any]) -> dict[str, Any]:
    hour = int(row["hour"])
    started_at, ended_at = _iso_hour(day, hour)
    event_id = f"legacy-input:{day}:{hour:02d}"
    metrics = {
        "keystrokes": int(_num(row, "keystrokes")),
        "chars_typed": int(_num(row, "chars_typed")),
        "mouse_distance_m": round(_num(row, "mouse_distance_m"), 4),
        "saves": int(_num(row, "saves")),
        "copies": int(_num(row, "copies")),
        "pastes": int(_num(row, "pastes")),
        "chars_pasted": int(_num(row, "chars_pasted")),
        "active_seconds": 3600.0,
        "legacy_hour": hour,
    }
    event = {
        "event_id": event_id,
        "event_type": "minute_rollup",
        "timestamp": ended_at,
        "bucket_start": started_at,
        "metrics": metrics,
        "dimensions": {
            "focus_category": "legacy",
            "privacy_level": "redacted",
            "source_file": f"{day}.json",
        },
    }
    event["checksum"] = _hash(event)
    return event


def _batch(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    day = str(payload.get("date") or path.stem)
    rows = payload.get("hourly") or []
    events = [_event(day, row) for row in rows if isinstance(row, dict) and _has_activity(row)]
    started_at = f"{day}T00:00:00Z"
    ended_at = f"{day}T23:59:59Z"
    return {
        "schema_version": 1,
        "source": SOURCE,
        "host": {"hostname": socket.gethostname(), "platform": platform.platform()},
        "session_id": f"legacy-input-log:{day}",
        "batch_id": f"legacy-input-log:{day}",
        "started_at": started_at,
        "ended_at": ended_at,
        "events": events,
    }


def _post(batch: dict[str, Any]) -> dict[str, Any]:
    body = json.dumps(batch, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    headers = {"Content-Type": "application/json", "User-Agent": "agent-ledger-input-log-import/1"}
    if API_KEY:
        headers["x-api-key"] = API_KEY
    request = Request(f"{API_URL}/api/telemetry/input/batches", data=body, headers=headers, method="POST")
    try:
        with urlopen(request, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"API returned {exc.code}: {detail}") from exc


def _paths(args: argparse.Namespace) -> list[Path]:
    if args.files:
        return [Path(item).resolve() for item in args.files]
    paths = sorted(INPUT_LOG_DIR.glob("*.json"))
    if args.since:
        paths = [path for path in paths if path.stem >= args.since]
    if args.until:
        paths = [path for path in paths if path.stem <= args.until]
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--since", help="Import YYYY-MM-DD and later.")
    parser.add_argument("--until", help="Import up to YYYY-MM-DD.")
    parser.add_argument("--files", nargs="*", help="Specific legacy JSON files to import.")
    parser.add_argument("--dry-run", action="store_true", help="Parse and summarize without POSTing.")
    args = parser.parse_args()

    parsed = 0
    failed = 0
    posted = 0
    inserted = 0
    duplicates = 0
    skipped_empty = 0

    for path in _paths(args):
        try:
            batch = _batch(path)
            parsed += 1
            if not batch["events"]:
                skipped_empty += 1
                print(f"{path.name}: events=0 skipped")
                continue
            if args.dry_run:
                print(f"{path.name}: events={len(batch['events'])} dry_run")
                continue
            result = _post(batch)
            posted += 1
            inserted += int(result.get("inserted", 0) or 0)
            duplicates += int(result.get("duplicates", 0) or 0)
            print(f"{path.name}: received={result.get('received')} inserted={result.get('inserted')} duplicates={result.get('duplicates')}")
        except Exception as exc:
            failed += 1
            print(f"{path.name}: failed={exc}", file=sys.stderr)

    print(
        "summary "
        f"parsed={parsed} posted={posted} inserted={inserted} duplicates={duplicates} "
        f"skipped_empty={skipped_empty} failed={failed}"
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
