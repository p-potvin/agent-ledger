#!/usr/bin/env python3
"""
VaultWares input tracker.

Collects privacy-safe input metrics, batches them to vaultwares-api, and
falls back to append-only JSONL spool files when the API is unavailable.

No raw typed text, clipboard contents, secrets, or unhashed window titles are
written by this process.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
import platform
import socket
import sys
import threading
import time
import traceback
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict
from urllib.error import URLError
from urllib.request import Request, urlopen

try:
    import pyperclip

    HAS_CLIPBOARD = True
except ImportError:
    HAS_CLIPBOARD = False

try:
    from pynput import keyboard, mouse
except ImportError:
    sys.exit("pynput not found. Run: pip install pynput")

SCRIPT_DIR = Path(__file__).parent.resolve()
ROOT_DIR = SCRIPT_DIR.parent
SPOOL_DIR = Path(os.environ.get("VW_INPUT_SPOOL_DIR") or (ROOT_DIR / "input-spool"))
API_URL = (os.environ.get("VW_API_URL") or os.environ.get("VW_PIPELINES_URL") or "http://127.0.0.1:9001").rstrip("/")
API_KEY = os.environ.get("VW_PIPELINES_API_KEY") or os.environ.get("VW_TELEMETRY_API_KEY") or ""
FLUSH_EVERY = max(10, int(os.environ.get("VW_INPUT_BATCH_SECONDS", "60")))
STATE_DIR = Path(os.environ.get("VW_INPUT_STATE_DIR") or (ROOT_DIR / "input-state"))
HEALTH_PATH = STATE_DIR / "input-tracker-health.json"
ERROR_PATH = STATE_DIR / "input-tracker-errors.jsonl"
LOCK_PATH = STATE_DIR / "input-tracker.lock"
PX_PER_METER = 96 / 0.0254
SOURCE = "agent-ledger-input-tracker"
SESSION_ID = f"{socket.gethostname()}-{uuid.uuid4().hex[:12]}"
_lock_handle = None

_lock = threading.Lock()
_mouse_last = None
_mouse_last_time = 0.0
_ctrl_held = False
_shift_held = False
_last_key_time = None
_last_activity_time = time.monotonic()
_seq = 0

_acc: Dict[str, Any] = {
    "keystrokes": 0,
    "chars_typed": 0,
    "backspaces": 0,
    "deletes": 0,
    "saves": 0,
    "copies": 0,
    "pastes": 0,
    "chars_pasted": 0,
    "undo_redo": 0,
    "shortcut_count": 0,
    "mouse_px": 0.0,
    "clicks": 0,
    "scroll_ticks": 0,
    "context_switches": 0,
    "micro_pauses": 0,
    "rest_blocks": 0,
    "active_seconds": 0.0,
    "key_latency_buckets": {"lt_120ms": 0, "120_250ms": 0, "250_500ms": 0, "500_1000ms": 0, "gt_1000ms": 0},
    "click_hotspots": {},
}
_focus_category = "unknown"
_window_hash = "redacted"

_CTRL_KEYS = {keyboard.Key.ctrl_l, keyboard.Key.ctrl_r}
_SHIFT_KEYS = {keyboard.Key.shift, keyboard.Key.shift_r}


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt: datetime) -> str:
    return dt.isoformat().replace("+00:00", "Z")


def _hash(value: str) -> str:
    if not value:
        return "redacted"
    return hashlib.sha256(value.encode("utf-8", errors="ignore")).hexdigest()[:16]


def _atomic_write_json(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    tmp.replace(path)


def _health(status: str, **extra: Any) -> None:
    payload = {
        "status": status,
        "session_id": SESSION_ID,
        "pid": os.getpid(),
        "api_url": API_URL,
        "spool_dir": str(SPOOL_DIR),
        "updated_at": _iso(_utc_now()),
        "privacy": {
            "raw_text": False,
            "clipboard_contents": False,
            "window_titles": "hashed_or_redacted",
        },
        **extra,
    }
    try:
        _atomic_write_json(HEALTH_PATH, payload)
    except Exception:
        pass


def _error(context: str, exc: BaseException) -> None:
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        row = {
            "timestamp": _iso(_utc_now()),
            "session_id": SESSION_ID,
            "pid": os.getpid(),
            "context": context,
            "error_type": type(exc).__name__,
            "message": str(exc)[:500],
            "traceback": traceback.format_exc(limit=4),
        }
        with ERROR_PATH.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(row, ensure_ascii=False, separators=(",", ":"), default=str) + "\n")
    except Exception:
        pass


def _acquire_single_instance() -> bool:
    global _lock_handle
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    _lock_handle = LOCK_PATH.open("a+", encoding="utf-8")
    try:
        if platform.system().lower() == "windows":
            import msvcrt

            msvcrt.locking(_lock_handle.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl

            fcntl.flock(_lock_handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        _health("duplicate_exit", message="another tracker instance holds the lock")
        return False
    _lock_handle.seek(0)
    _lock_handle.truncate()
    _lock_handle.write(str(os.getpid()))
    _lock_handle.flush()
    return True


def _foreground_window() -> tuple[str, str]:
    if platform.system().lower() != "windows":
        return "unknown", "redacted"
    try:
        import ctypes

        hwnd = ctypes.windll.user32.GetForegroundWindow()
        length = ctypes.windll.user32.GetWindowTextLengthW(hwnd)
        buff = ctypes.create_unicode_buffer(length + 1)
        ctypes.windll.user32.GetWindowTextW(hwnd, buff, length + 1)
        title = (buff.value or "").strip()
    except Exception:
        return "unknown", "redacted"
    lowered = title.lower()
    if any(token in lowered for token in ("code", "visual studio", "cursor", "terminal", "powershell", "cmd", "git")):
        category = "development"
    elif any(token in lowered for token in ("browser", "chrome", "firefox", "edge", "docs", "github")):
        category = "browser"
    elif any(token in lowered for token in ("slack", "teams", "discord", "mail", "outlook")):
        category = "communication"
    else:
        category = "other" if title else "unknown"
    return category, _hash(title)


def _touch_activity() -> None:
    global _last_activity_time
    now = time.monotonic()
    gap = now - _last_activity_time
    if 30 <= gap < 300:
        _acc["micro_pauses"] += 1
    elif gap >= 300:
        _acc["rest_blocks"] += 1
    _last_activity_time = now


def _record_latency() -> None:
    global _last_key_time
    now = time.monotonic()
    if _last_key_time is not None:
        delta_ms = (now - _last_key_time) * 1000
        if delta_ms < 120:
            bucket = "lt_120ms"
        elif delta_ms < 250:
            bucket = "120_250ms"
        elif delta_ms < 500:
            bucket = "250_500ms"
        elif delta_ms < 1000:
            bucket = "500_1000ms"
        else:
            bucket = "gt_1000ms"
        _acc["key_latency_buckets"][bucket] += 1
    _last_key_time = now


def _combo_char(key: Any) -> str | None:
    try:
        raw = key.char if hasattr(key, "char") and key.char else None
        if not raw:
            return None
        if len(raw) == 1 and ord(raw) < 32:
            return chr(ord(raw) + 96)
        return raw.lower()
    except Exception:
        return None


def _on_press(key: Any) -> None:
    global _ctrl_held, _shift_held
    with _lock:
        _touch_activity()
        _record_latency()
        _acc["keystrokes"] += 1

        if key in _CTRL_KEYS:
            _ctrl_held = True
            return
        if key in _SHIFT_KEYS:
            _shift_held = True
            return
        if key == keyboard.Key.backspace:
            _acc["backspaces"] += 1
            return
        if key == keyboard.Key.delete:
            _acc["deletes"] += 1
            return

        if _ctrl_held:
            ch = _combo_char(key)
            if ch:
                _acc["shortcut_count"] += 1
            if ch == "s":
                _acc["saves"] += 1
            elif ch == "c":
                _acc["copies"] += 1
            elif ch == "v":
                _acc["pastes"] += 1
                if HAS_CLIPBOARD:
                    try:
                        _acc["chars_pasted"] += len(pyperclip.paste() or "")
                    except Exception:
                        pass
            elif ch in {"z", "y"}:
                _acc["undo_redo"] += 1
            return

        try:
            if hasattr(key, "char") and key.char and len(key.char) == 1:
                _acc["chars_typed"] += 1
        except Exception:
            pass
        if key == keyboard.Key.space:
            _acc["chars_typed"] += 1


def _on_release(key: Any) -> None:
    global _ctrl_held, _shift_held
    with _lock:
        if key in _CTRL_KEYS:
            _ctrl_held = False
        if key in _SHIFT_KEYS:
            _shift_held = False


def _on_move(x: int, y: int) -> None:
    global _mouse_last, _mouse_last_time
    now = time.monotonic()
    with _lock:
        _touch_activity()
        if _mouse_last is not None and (now - _mouse_last_time) < 300:
            dx = x - _mouse_last[0]
            dy = y - _mouse_last[1]
            _acc["mouse_px"] += math.sqrt(dx * dx + dy * dy)
        _mouse_last = (x, y)
        _mouse_last_time = now


def _on_click(x: int, y: int, button: Any, pressed: bool) -> None:
    if not pressed:
        return
    with _lock:
        _touch_activity()
        _acc["clicks"] += 1
        key = f"{max(0, int(x // 160))}:{max(0, int(y // 120))}"
        _acc["click_hotspots"][key] = _acc["click_hotspots"].get(key, 0) + 1


def _on_scroll(x: int, y: int, dx: int, dy: int) -> None:
    with _lock:
        _touch_activity()
        _acc["scroll_ticks"] += abs(dx) + abs(dy)


def _snapshot() -> Dict[str, Any]:
    global _focus_category, _window_hash
    with _lock:
        snap = json.loads(json.dumps(_acc))
        for key in _acc:
            if isinstance(_acc[key], dict):
                _acc[key] = {k: 0 for k in _acc[key]}
            else:
                _acc[key] = 0.0 if isinstance(_acc[key], float) else 0
        category, window_hash = _foreground_window()
        if category != _focus_category:
            snap["context_switches"] += 1
        _focus_category = category
        _window_hash = window_hash
    return snap


def _build_batch(started_at: datetime, ended_at: datetime, snap: Dict[str, Any]) -> Dict[str, Any] | None:
    global _seq
    if snap["keystrokes"] == 0 and snap["mouse_px"] == 0 and snap["clicks"] == 0 and snap["scroll_ticks"] == 0:
        return None
    _seq += 1
    duration = max(1.0, (ended_at - started_at).total_seconds())
    mouse_px = float(snap.pop("mouse_px", 0.0))
    metrics = {**snap, "active_seconds": duration, "mouse_distance_m": round(mouse_px / PX_PER_METER, 4)}
    event = {
        "event_id": f"{SESSION_ID}:{_seq}",
        "event_type": "minute_rollup",
        "timestamp": _iso(ended_at),
        "bucket_start": _iso(started_at),
        "metrics": metrics,
        "dimensions": {
            "focus_category": _focus_category,
            "window_hash": _window_hash,
            "privacy_level": "redacted",
        },
    }
    event["checksum"] = _hash(json.dumps(event, sort_keys=True, separators=(",", ":"), default=str))
    return {
        "schema_version": 1,
        "source": SOURCE,
        "host": {"hostname": socket.gethostname(), "platform": platform.platform()},
        "session_id": SESSION_ID,
        "batch_id": f"{SESSION_ID}:{_seq}:{uuid.uuid4().hex[:8]}",
        "started_at": _iso(started_at),
        "ended_at": _iso(ended_at),
        "events": [event],
    }


def _post_batch(batch: Dict[str, Any]) -> None:
    body = json.dumps(batch, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    headers = {"Content-Type": "application/json", "User-Agent": "agent-ledger-input-tracker/2"}
    if API_KEY:
        headers["x-api-key"] = API_KEY
    request = Request(f"{API_URL}/api/telemetry/input/batches", data=body, headers=headers, method="POST")
    with urlopen(request, timeout=5) as response:
        if response.status >= 300:
            raise URLError(f"status {response.status}")


def _spool_batch(batch: Dict[str, Any]) -> None:
    SPOOL_DIR.mkdir(parents=True, exist_ok=True)
    path = SPOOL_DIR / f"{datetime.now().strftime('%Y-%m-%d')}.jsonl"
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(batch, ensure_ascii=False, separators=(",", ":")) + "\n")
    _health("spooled", last_batch_id=batch.get("batch_id"), spool_file=str(path))


def _flush_loop() -> None:
    started_at = _utc_now()
    while True:
        time.sleep(FLUSH_EVERY)
        ended_at = _utc_now()
        try:
            snap = _snapshot()
            batch = _build_batch(started_at, ended_at, snap)
            started_at = ended_at
            if not batch:
                _health("online_idle", last_flush_at=_iso(ended_at))
                continue
            try:
                _post_batch(batch)
                _health("online", last_batch_id=batch.get("batch_id"), last_post_at=_iso(_utc_now()))
            except Exception as exc:
                _error("post_batch", exc)
                _spool_batch(batch)
        except Exception as exc:
            _error("flush_loop", exc)
            _health("error", message=str(exc)[:500])


def main() -> None:
    if not _acquire_single_instance():
        return
    _health("starting")
    thread = threading.Thread(target=_flush_loop, daemon=True)
    thread.start()
    kb = keyboard.Listener(on_press=_on_press, on_release=_on_release)
    ms = mouse.Listener(on_move=_on_move, on_click=_on_click, on_scroll=_on_scroll)
    kb.start()
    ms.start()
    _health("listening")
    kb.join()


if __name__ == "__main__":
    main()
