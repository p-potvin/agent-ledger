"""
backfill-input-logs.py
~~~~~~~~~~~~~~~~~~~~~~

One-shot converter for the legacy `input-logs/2026-MM-DD.json` files (hourly
aggregates, schemaVersion 1) into the new `/api/telemetry/input/batches` shape
the API (vaultwares-api) accepts.

Why this exists
---------------
The new tracker (track-input.py) writes minute-rollup events and POSTs them to
vaultwares-api which persists them in Postgres. The old tracker wrote one
JSON-per-day with hour buckets to `input-logs/`. Those 9 days never made it
into the DB. The user asked to convert + backfill rather than drop.

Idempotency
-----------
Each emitted event has a stable id of the form `legacy:<date>:<hour>`. The API
dedupes via `ON CONFLICT (event_id) DO NOTHING` (see
vaultwares-api/migrations/telemetry/001_input_telemetry.sql), so re-running
this script is safe — it will hit `duplicates` instead of `inserted`.

Run
---
Set VW_TELEMETRY_API_KEY (defaults to the value from vaultwares-api/.env if
present), then:

    python scripts\backfill-input-logs.py

Pass --dry-run to print the batches that would be POSTed without sending them.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Tuple

import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
LEGACY_DIR = ROOT / "input-logs"
DEFAULT_API_URL = "http://127.0.0.1:9001"
DEFAULT_SESSION_ID = "legacy-hourly-import"
SOURCE = "agent-ledger-legacy"

# Field aliases between legacy hourly schema and the new metrics dict. The new
# schema uses the same names for these counters, so this is a passthrough — we
# whitelist explicitly so unexpected keys don't leak through.
METRIC_KEYS = (
    "keystrokes",
    "chars_typed",
    "mouse_distance_m",
    "saves",
    "copies",
    "pastes",
    "chars_pasted",
)


def _api_url() -> str:
    return (os.environ.get("VW_API_URL") or DEFAULT_API_URL).rstrip("/")


def _api_key() -> str:
    key = os.environ.get("VW_TELEMETRY_API_KEY") or ""
    if not key:
        env_path = ROOT.parent / "vaultwares-api" / ".env"
        if env_path.exists():
            for line in env_path.read_text(encoding="utf-8").splitlines():
                if line.startswith("VW_TELEMETRY_API_KEY="):
                    key = line.split("=", 1)[1].strip()
                    break
    return key


def _load_day(path: Path) -> Tuple[str, List[Dict[str, Any]]]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    date_str = str(raw.get("date") or path.stem)
    hourly = raw.get("hourly") or []
    return date_str, hourly


def _build_batch(date_str: str, hourly: List[Dict[str, Any]]) -> Dict[str, Any]:
    # Use the date as ISO so the parser handles it as midnight UTC.
    day = datetime.fromisoformat(date_str).replace(tzinfo=timezone.utc)
    events: List[Dict[str, Any]] = []
    nonzero = 0
    for bucket in hourly:
        hour = int(bucket.get("hour", 0))
        # Skip empty hours entirely — they add noise without value.
        metrics = {k: bucket.get(k, 0) for k in METRIC_KEYS}
        if not any(v for v in metrics.values()):
            continue
        nonzero += 1
        bucket_start = day + timedelta(hours=hour)
        events.append(
            {
                "event_id": f"legacy:{date_str}:{hour:02d}",
                "event_type": "minute_rollup",
                "timestamp": bucket_start.isoformat(),
                "bucket_start": bucket_start.isoformat(),
                "metrics": metrics,
                "dimensions": {
                    "legacy_source": "input-logs",
                    "granularity": "hour",
                },
            }
        )
    # Always emit at least one event so the API doesn't 422 on min_length=1.
    # For fully-empty days, emit a sentinel zero-metric event so the day is on
    # record. This is safe because the API dedupes by event_id.
    if not events:
        bucket_start = day
        events.append(
            {
                "event_id": f"legacy:{date_str}:sentinel",
                "event_type": "minute_rollup",
                "timestamp": bucket_start.isoformat(),
                "bucket_start": bucket_start.isoformat(),
                "metrics": {k: 0 for k in METRIC_KEYS},
                "dimensions": {
                    "legacy_source": "input-logs",
                    "granularity": "hour",
                    "note": "empty-day-sentinel",
                },
            }
        )
    return {
        "schema_version": 1,
        "source": SOURCE,
        "host": {"origin": "input-logs", "note": "legacy hourly backfill"},
        "session_id": DEFAULT_SESSION_ID,
        "batch_id": f"legacy:{date_str}",
        "started_at": day.isoformat(),
        "ended_at": (day + timedelta(days=1, microseconds=-1)).isoformat(),
        "events": events,
    }, nonzero


def _post(batch: Dict[str, Any]) -> Tuple[int, Dict[str, Any]]:
    payload = json.dumps(batch).encode("utf-8")
    url = f"{_api_url()}/api/telemetry/input/batches"
    req = urllib.request.Request(
        url,
        data=payload,
        method="POST",
        headers={
            "content-type": "application/json",
            "accept": "application/json",
            "x-api-key": _api_key(),
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            return resp.status, body
    except urllib.error.HTTPError as exc:
        try:
            body = json.loads(exc.read().decode("utf-8"))
        except Exception:
            body = {"error": exc.reason}
        return exc.code, body


def main() -> int:
    parser = argparse.ArgumentParser(description="Backfill legacy input-logs/*.json into the API.")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be sent without POSTing.")
    parser.add_argument(
        "--include-corrupt",
        action="store_true",
        help="Also try to parse and ingest *.json.corrupt files.",
    )
    args = parser.parse_args()

    if not LEGACY_DIR.exists():
        print(f"No legacy directory at {LEGACY_DIR}", file=sys.stderr)
        return 0

    files = sorted(p for p in LEGACY_DIR.glob("*.json") if not p.name.endswith(".corrupt"))
    if args.include_corrupt:
        files += sorted(LEGACY_DIR.glob("*.json.corrupt"))
    if not files:
        print("No legacy input-logs to backfill.")
        return 0

    if not args.dry_run and not _api_key():
        print("VW_TELEMETRY_API_KEY not set and not findable in vaultwares-api/.env", file=sys.stderr)
        return 2

    grand_inserted = grand_duplicates = grand_errors = 0
    for path in files:
        try:
            date_str, hourly = _load_day(path)
        except Exception as exc:
            print(f"  ✗ {path.name}: parse failed — {exc}")
            grand_errors += 1
            continue

        batch, nonzero = _build_batch(date_str, hourly)
        if args.dry_run:
            print(f"  [dry] {path.name}: {len(batch['events'])} events ({nonzero} non-empty)")
            continue

        status, body = _post(batch)
        if status == 200:
            ins = int(body.get("inserted", 0))
            dup = int(body.get("duplicates", 0))
            grand_inserted += ins
            grand_duplicates += dup
            print(f"  ✓ {path.name}: events={len(batch['events'])} inserted={ins} duplicates={dup}")
        else:
            grand_errors += 1
            print(f"  ✗ {path.name}: HTTP {status} body={body}")

    print(
        f"\nDone. inserted={grand_inserted} duplicates={grand_duplicates} errors={grand_errors}"
        f" across {len(files)} file(s)."
    )
    return 0 if grand_errors == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
