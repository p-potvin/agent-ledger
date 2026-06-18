"""
backfill-agent-ledger-to-api.py
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Walk every event JSON under `events/` and `history/`, POST them in batches to
`/api/ledger/agent/events/batches` so vaultwares-api becomes system of record.

Why this exists
---------------
record-agent-change.ps1 already does dual-write for *new* events (it always
calls the API unless VW_AGENT_LEDGER_API_SYNC=0). But the ~2,100 historic
events sitting on disk pre-date that wiring and were never POSTed. This is
the one-shot backfill.

Idempotency
-----------
The API dedupes via content_hash (or the event `id`) — see
vaultwares-api/app/routers/telemetry/agent_ledger_db.py. Safe to re-run.

Run
---
Set VW_TELEMETRY_API_KEY (or it falls back to vaultwares-api/.env), then:

    python scripts\backfill-agent-ledger-to-api.py

Pass --dry-run to count without POSTing. Pass --reset to ignore the resume
checkpoint and re-walk everything.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List

import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
DIRS = (ROOT / "events", ROOT / "history")
DEFAULT_API_URL = "http://100.67.25.118:9001"
CHECKPOINT = ROOT / ".backfill-agent-ledger-progress.json"
BATCH_SIZE = 250  # well under the API's max 5000


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


def _walk_files() -> Iterable[Path]:
    for base in DIRS:
        if not base.exists():
            continue
        for path in sorted(base.rglob("*.json")):
            yield path


def _load_event(path: Path) -> Dict[str, Any] | None:
    try:
        # utf-8-sig handles both BOM-prefixed (PowerShell default) and plain.
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception as exc:
        print(f"  ! skip {path.relative_to(ROOT)}: parse failed - {exc}", file=sys.stderr)
        return None
    if not isinstance(data, dict):
        return None
    # API requires `id`. Most events have one already; fall back to stem.
    if not data.get("id"):
        data["id"] = path.stem
    return data


def _post_batch(events: List[Dict[str, Any]]) -> Dict[str, Any]:
    payload = json.dumps({"events": events}).encode("utf-8")
    url = f"{_api_url()}/api/ledger/agent/events/batches"
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
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _load_checkpoint() -> set[str]:
    if not CHECKPOINT.exists():
        return set()
    try:
        return set(json.loads(CHECKPOINT.read_text(encoding="utf-8")).get("done", []))
    except Exception:
        return set()


def _save_checkpoint(done: set[str]) -> None:
    CHECKPOINT.write_text(json.dumps({"done": sorted(done)}, indent=2), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--reset", action="store_true", help="Ignore checkpoint, re-walk everything.")
    parser.add_argument("--batch-size", type=int, default=BATCH_SIZE)
    args = parser.parse_args()

    if not args.dry_run and not _api_key():
        print("VW_TELEMETRY_API_KEY not set and not findable in vaultwares-api/.env", file=sys.stderr)
        return 2

    done = set() if args.reset else _load_checkpoint()
    files = [p for p in _walk_files() if str(p.relative_to(ROOT)) not in done]
    print(f"Walking {len(files)} file(s) (checkpoint had {len(done)} already done)")

    batch: List[Dict[str, Any]] = []
    batch_paths: List[str] = []
    totals = {"received": 0, "inserted": 0, "duplicates": 0, "errors": 0, "skipped": 0}

    def flush() -> None:
        nonlocal batch, batch_paths
        if not batch:
            return
        if args.dry_run:
            print(f"  [dry] would POST {len(batch)} events ({batch_paths[0]} .. {batch_paths[-1]})")
            for rel in batch_paths:
                done.add(rel)
            batch.clear()
            batch_paths.clear()
            return
        try:
            res = _post_batch(batch)
        except urllib.error.HTTPError as exc:
            body = ""
            try:
                body = exc.read().decode("utf-8")
            except Exception:
                pass
            print(f"  X HTTP {exc.code} on batch ({batch_paths[0]} .. {batch_paths[-1]}): {body[:200]}")
            totals["errors"] += len(batch)
            batch.clear()
            batch_paths.clear()
            return
        ins = int(res.get("inserted", 0))
        dup = int(res.get("duplicates", 0))
        rec = int(res.get("received", len(batch)))
        totals["received"] += rec
        totals["inserted"] += ins
        totals["duplicates"] += dup
        for rel in batch_paths:
            done.add(rel)
        _save_checkpoint(done)
        print(f"  + batch {len(batch)}: inserted={ins} duplicates={dup}  [{batch_paths[0]} .. {batch_paths[-1]}]")
        batch.clear()
        batch_paths.clear()

    for path in files:
        rel = str(path.relative_to(ROOT))
        ev = _load_event(path)
        if ev is None:
            totals["skipped"] += 1
            continue
        batch.append(ev)
        batch_paths.append(rel)
        if len(batch) >= args.batch_size:
            flush()
    flush()
    _save_checkpoint(done)

    print(
        f"\nDone. received={totals['received']} inserted={totals['inserted']}"
        f" duplicates={totals['duplicates']} errors={totals['errors']}"
        f" skipped={totals['skipped']}"
    )
    return 0 if totals["errors"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
