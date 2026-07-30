#!/usr/bin/env python3
"""
VaultWares input tracker.

Collects input metrics, batches them to vaultwares-api, and falls back to
append-only JSONL spool files when the API is unavailable.

Minute rollups avoid raw typed text. Natural path segments intentionally store
raw key presses during owner opt-in behavior capture windows.
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
API_URL = (os.environ.get("VW_API_URL") or "https://api.vaultwares.ca").rstrip("/")
API_KEY = os.environ.get("VW_TELEMETRY_API_KEY") or ""
FLUSH_EVERY = max(10, int(os.environ.get("VW_INPUT_BATCH_SECONDS", "60")))
STATE_DIR = Path(os.environ.get("VW_INPUT_STATE_DIR") or (ROOT_DIR / "input-state"))
HEALTH_PATH = STATE_DIR / "input-tracker-health.json"
ERROR_PATH = STATE_DIR / "input-tracker-errors.jsonl"
LOCK_PATH = STATE_DIR / "input-tracker.lock"
PX_PER_METER = 96 / 0.0254
NATURAL_PATH_MAX_POINTS = max(100, int(os.environ.get("VW_INPUT_NATURAL_PATH_MAX_POINTS", "2000")))
NATURAL_PATH_MAX_KEYS = max(100, int(os.environ.get("VW_INPUT_NATURAL_PATH_MAX_KEYS", "2000")))
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
_active_block_started_time = _last_activity_time
_last_focus_check_time = 0.0
_focus_started_time = _last_activity_time
_focus_initialized = False
_seq = 0
_natural_path_seq = 0
_natural_path = None
_natural_paths = []

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
    "pause_blocks": 0,
    "pauses_5m_20m": 0,
    "healthy_pause_blocks": 0,
    "pauses_20m_60m": 0,
    "time_off_blocks": 0,
    "pauses_1h_plus": 0,
    "active_starts_after_rest": 0,
    "rest_gap_seconds_total": 0.0,
    "rest_gap_seconds_max": 0.0,
    "focus_streak_seconds_total": 0.0,
    "focus_streak_samples": 0,
    "longest_focus_streak_seconds": 0.0,
    "switch_recovery_seconds_total": 0.0,
    "switch_recovery_samples": 0,
    "longest_active_block_seconds": 0.0,
    "active_seconds": 0.0,
    "key_latency_buckets": {"lt_120ms": 0, "120_250ms": 0, "250_500ms": 0, "500_1000ms": 0, "gt_1000ms": 0},
    "click_hotspots": {},
}
_focus_category = "unknown"
_window_hash = "redacted"
_window_name = "unknown"

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


def _is_key(key: Any, candidates: set[Any]) -> bool:
    try:
        return key in candidates
    except TypeError:
        return False


def _safe_window_label(process_name: str, title: str) -> tuple[str, str]:
    haystack = f"{process_name} {title}".lower()
    rules = [
        ("firefox", "browser", "Firefox"),
        ("chrome", "browser", "Chrome"),
        ("msedge", "browser", "Edge"),
        ("edge", "browser", "Edge"),
        ("explorer", "browser", "Explorer"),
        ("github", "browser", "GitHub"),
        ("docs", "browser", "Docs"),
        ("code", "development", "Visual Studio Code"),
        ("cursor", "development", "Cursor"),
        ("devenv", "development", "Visual Studio"),
        ("visual studio", "development", "Visual Studio"),
        ("terminal", "development", "Terminal"),
        ("powershell", "development", "PowerShell"),
        ("pwsh", "development", "PowerShell"),
        ("cmd", "development", "Command Prompt"),
        ("git", "development", "Git"),
        ("python", "development", "Python"),
        ("slack", "communication", "Slack"),
        ("teams", "communication", "Teams"),
        ("discord", "communication", "Discord"),
        ("outlook", "communication", "Outlook"),
        ("mail", "communication", "Mail"),
        ("comfy", "media", "ComfyUI"),
        ("ollama", "ai", "Ollama"),
        ("obsidian", "notes", "Obsidian"),
        ("notepad", "notes", "Notepad"),
        ("settings", "system", "Settings"),
        ("taskmgr", "system", "Task Manager"),
    ]
    for token, category, label in rules:
        if token in haystack:
            return category, label
    cleaned = process_name.rsplit("\\", 1)[-1].rsplit("/", 1)[-1].lower()
    if cleaned.endswith(".exe"):
        cleaned = cleaned[:-4]
    if cleaned:
        return "other", cleaned[:40]
    return ("unknown" if not title else "other"), "unknown"


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
            "raw_text": "natural_paths_raw_keys_owner_opt_in",
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


def _foreground_window() -> tuple[str, str, str]:
    if platform.system().lower() != "windows":
        return "unknown", "redacted", "unknown"
    try:
        import ctypes

        hwnd = ctypes.windll.user32.GetForegroundWindow()
        length = ctypes.windll.user32.GetWindowTextLengthW(hwnd)
        buff = ctypes.create_unicode_buffer(length + 1)
        ctypes.windll.user32.GetWindowTextW(hwnd, buff, length + 1)
        title = (buff.value or "").strip()
        pid = ctypes.c_ulong()
        ctypes.windll.user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        process_name = ""
        if pid.value:
            access = 0x1000
            handle = ctypes.windll.kernel32.OpenProcess(access, False, pid.value)
            if handle:
                try:
                    exe_buff = ctypes.create_unicode_buffer(260)
                    size = ctypes.c_ulong(len(exe_buff))
                    if ctypes.windll.kernel32.QueryFullProcessImageNameW(handle, 0, exe_buff, ctypes.byref(size)):
                        process_name = exe_buff.value
                finally:
                    ctypes.windll.kernel32.CloseHandle(handle)
    except Exception:
        return "unknown", "redacted", "unknown"
    category, window_name = _safe_window_label(process_name, title)
    return category, _hash(title), window_name


def _spool_backlog_stats() -> tuple[int, int]:
    try:
        if not SPOOL_DIR.exists():
            return 0, 0
        batches = 0
        bytes_total = 0
        for path in SPOOL_DIR.glob("*.jsonl"):
            try:
                bytes_total += path.stat().st_size
                with path.open("r", encoding="utf-8") as handle:
                    batches += sum(1 for line in handle if line.strip())
            except OSError:
                continue
        return batches, bytes_total
    except Exception:
        return 0, 0


def _refresh_focus(now: float, recovery_gap: float) -> None:
    global _focus_category, _window_hash, _window_name, _last_focus_check_time, _focus_started_time, _focus_initialized
    if now - _last_focus_check_time < 1.0:
        return
    _last_focus_check_time = now
    category, window_hash, window_name = _foreground_window()
    changed = category != _focus_category or window_name != _window_name
    if not _focus_initialized:
        _focus_initialized = True
        _focus_started_time = now
        changed = False
    if changed:
        ended_streak = max(0.0, now - _focus_started_time)
        _acc["context_switches"] += 1
        _acc["focus_streak_seconds_total"] += ended_streak
        _acc["focus_streak_samples"] += 1
        _acc["longest_focus_streak_seconds"] = max(float(_acc["longest_focus_streak_seconds"]), ended_streak)
        _acc["switch_recovery_seconds_total"] += max(0.0, recovery_gap)
        _acc["switch_recovery_samples"] += 1
        _focus_started_time = now
        _start_natural_path("context_switch", now)
    else:
        _acc["longest_focus_streak_seconds"] = max(float(_acc["longest_focus_streak_seconds"]), max(0.0, now - _focus_started_time))
    _focus_category = category
    _window_hash = window_hash
    _window_name = window_name


def _touch_activity() -> None:
    global _last_activity_time, _active_block_started_time
    now = time.monotonic()
    gap = now - _last_activity_time
    if 30 <= gap < 300:
        _acc["micro_pauses"] += 1
        _start_natural_path("idle_resume", now, idle_gap_seconds=gap)
    elif gap >= 300:
        _acc["rest_blocks"] += 1
        if 300 <= gap < 1200:
            _acc["pause_blocks"] += 1
            _acc["pauses_5m_20m"] += 1
        elif 1200 <= gap < 3600:
            _acc["healthy_pause_blocks"] += 1
            _acc["pauses_20m_60m"] += 1
        else:
            _acc["time_off_blocks"] += 1
            _acc["pauses_1h_plus"] += 1
        _acc["active_starts_after_rest"] += 1
        _acc["rest_gap_seconds_total"] += gap
        _acc["rest_gap_seconds_max"] = max(float(_acc["rest_gap_seconds_max"]), gap)
        active_block = max(0.0, _last_activity_time - _active_block_started_time)
        _acc["longest_active_block_seconds"] = max(float(_acc["longest_active_block_seconds"]), active_block)
        _active_block_started_time = now
        _start_natural_path("idle_resume", now, idle_gap_seconds=gap)
    else:
        active_block = max(0.0, now - _active_block_started_time)
        _acc["longest_active_block_seconds"] = max(float(_acc["longest_active_block_seconds"]), active_block)
    _refresh_focus(now, gap)
    _last_activity_time = now


def _context_snapshot() -> Dict[str, Any]:
    return {
        "focus_category": _focus_category,
        "window_name": _window_name,
        "window_hash": _window_hash,
    }


def _start_natural_path(trigger: str, now: float, idle_gap_seconds: float | None = None) -> None:
    global _natural_path, _natural_path_seq
    if _natural_path is not None:
        return
    _natural_path_seq += 1
    started_at = _utc_now()
    _natural_path = {
        "path_id": f"{SESSION_ID}:path:{_natural_path_seq}",
        "trigger": trigger,
        "started_at": _iso(started_at),
        "started_monotonic": now,
        "start_context": _context_snapshot(),
        "mouse_path": [],
        "key_presses": [],
        "distance_px": 0.0,
        "idle_gap_seconds": round(idle_gap_seconds, 3) if idle_gap_seconds is not None else None,
    }


def _key_payload(key: Any, now: float) -> Dict[str, Any]:
    value = None
    kind = "special"
    try:
        if hasattr(key, "char") and key.char is not None:
            value = str(key.char)
            kind = "char"
    except Exception:
        value = None
    if value is None and key == keyboard.Key.space:
        value = " "
        kind = "char"
    if value is None:
        value = str(key).replace("Key.", "")
    elapsed_ms = 0
    if _natural_path is not None:
        elapsed_ms = int(max(0.0, now - float(_natural_path["started_monotonic"])) * 1000)
    return {
        "t_ms": elapsed_ms,
        "value": value,
        "kind": kind,
        "ctrl": bool(_ctrl_held),
        "shift": bool(_shift_held),
    }


def _append_natural_key(key: Any, now: float) -> None:
    if _natural_path is None:
        return
    keys = _natural_path["key_presses"]
    if len(keys) < NATURAL_PATH_MAX_KEYS:
        keys.append(_key_payload(key, now))


def _append_natural_point(x: int, y: int, now: float) -> None:
    if _natural_path is None:
        return
    points = _natural_path["mouse_path"]
    elapsed_ms = int(max(0.0, now - float(_natural_path["started_monotonic"])) * 1000)
    if points:
        dx = x - int(points[-1]["x"])
        dy = y - int(points[-1]["y"])
        _natural_path["distance_px"] += math.sqrt(dx * dx + dy * dy)
    if len(points) < NATURAL_PATH_MAX_POINTS:
        points.append({"t_ms": elapsed_ms, "x": int(x), "y": int(y)})


def _finalize_natural_path(now: float, ended_reason: str, click_target: Dict[str, Any] | None = None) -> None:
    global _natural_path
    if _natural_path is None:
        return
    duration_ms = int(max(0.0, now - float(_natural_path["started_monotonic"])) * 1000)
    points = _natural_path["mouse_path"]
    keys = _natural_path["key_presses"]
    if not points and not keys and not click_target:
        _natural_path = None
        return
    distance_px = float(_natural_path.get("distance_px") or 0.0)
    finished = {
        "path_id": _natural_path["path_id"],
        "trigger": _natural_path["trigger"],
        "started_at": _natural_path["started_at"],
        "ended_at": _iso(_utc_now()),
        "duration_ms": duration_ms,
        "mouse_path": points,
        "key_presses": keys,
        "click_target": click_target or {},
        "stats": {
            "point_count": len(points),
            "key_count": len(keys),
            "distance_px": round(distance_px, 3),
            "distance_m": round(distance_px / PX_PER_METER, 4),
            "idle_gap_seconds": _natural_path.get("idle_gap_seconds"),
            "ended_reason": ended_reason,
        },
        "start_context": _natural_path["start_context"],
        "end_context": _context_snapshot(),
    }
    _natural_paths.append(finished)
    _natural_path = None


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
        now = time.monotonic()
        _append_natural_key(key, now)
        _acc["keystrokes"] += 1

        if _is_key(key, _CTRL_KEYS):
            _ctrl_held = True
            return
        if _is_key(key, _SHIFT_KEYS):
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
        if _is_key(key, _CTRL_KEYS):
            _ctrl_held = False
        if _is_key(key, _SHIFT_KEYS):
            _shift_held = False


def _on_move(x: int, y: int) -> None:
    global _mouse_last, _mouse_last_time
    now = time.monotonic()
    with _lock:
        _touch_activity()
        _append_natural_point(x, y, now)
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
        click_target = {"x": int(x), "y": int(y), "button": str(button)}
        _finalize_natural_path(time.monotonic(), "click", click_target)


def _on_scroll(x: int, y: int, dx: int, dy: int) -> None:
    with _lock:
        _touch_activity()
        _acc["scroll_ticks"] += abs(dx) + abs(dy)


def _snapshot() -> Dict[str, Any]:
    with _lock:
        snap = json.loads(json.dumps(_acc))
        snap["natural_paths"] = json.loads(json.dumps(_natural_paths))
        _natural_paths.clear()
        now = time.monotonic()
        if _focus_initialized:
            current_focus_streak = max(0.0, now - _focus_started_time)
            snap["current_focus_streak_seconds"] = current_focus_streak
            snap["longest_focus_streak_seconds"] = max(float(snap["longest_focus_streak_seconds"]), current_focus_streak)
        current_active_block = max(0.0, now - _active_block_started_time)
        snap["longest_active_block_seconds"] = max(float(snap["longest_active_block_seconds"]), current_active_block)
        backlog_batches, backlog_bytes = _spool_backlog_stats()
        snap["spool_backlog_batches"] = backlog_batches
        snap["spool_backlog_bytes"] = backlog_bytes
        for key in _acc:
            if isinstance(_acc[key], dict):
                _acc[key] = {k: 0 for k in _acc[key]}
            else:
                _acc[key] = 0.0 if isinstance(_acc[key], float) else 0
    return snap


def _build_batch(started_at: datetime, ended_at: datetime, snap: Dict[str, Any]) -> Dict[str, Any] | None:
    global _seq
    natural_paths = snap.pop("natural_paths", [])
    has_rollup = not (snap["keystrokes"] == 0 and snap["mouse_px"] == 0 and snap["clicks"] == 0 and snap["scroll_ticks"] == 0)
    if not has_rollup and not natural_paths:
        return None
    _seq += 1
    duration = max(1.0, (ended_at - started_at).total_seconds())
    mouse_px = float(snap.pop("mouse_px", 0.0))
    metrics = {**snap, "active_seconds": duration, "mouse_distance_m": round(mouse_px / PX_PER_METER, 4)}
    events = []
    if has_rollup:
        event = {
            "event_id": f"{SESSION_ID}:{_seq}",
            "event_type": "minute_rollup",
            "timestamp": _iso(ended_at),
            "bucket_start": _iso(started_at),
            "metrics": metrics,
            "dimensions": {
                "focus_category": _focus_category,
                "window_name": _window_name,
                "window_hash": _window_hash,
                "privacy_level": "redacted",
            },
        }
        event["checksum"] = _hash(json.dumps(event, sort_keys=True, separators=(",", ":"), default=str))
        events.append(event)
    for index, path in enumerate(natural_paths, start=1):
        event = {
            "event_id": f"{path.get('path_id') or SESSION_ID + ':path:' + str(_seq) + ':' + str(index)}",
            "event_type": "natural_path",
            "timestamp": path.get("ended_at") or _iso(ended_at),
            "bucket_start": path.get("started_at") or _iso(started_at),
            "metrics": {
                "path_id": path.get("path_id"),
                "trigger": path.get("trigger"),
                "started_at": path.get("started_at"),
                "ended_at": path.get("ended_at"),
                "duration_ms": path.get("duration_ms", 0),
                "mouse_path": path.get("mouse_path") or [],
                "key_presses": path.get("key_presses") or [],
                "click_target": path.get("click_target") or {},
                "stats": path.get("stats") or {},
            },
            "dimensions": {
                "start_context": path.get("start_context") or {},
                "end_context": path.get("end_context") or {},
                "privacy_level": "raw_keys_owner_opt_in",
            },
        }
        event["checksum"] = _hash(json.dumps(event, sort_keys=True, separators=(",", ":"), default=str))
        events.append(event)
    return {
        "schema_version": 2,
        "source": SOURCE,
        "host": {"hostname": socket.gethostname(), "platform": platform.platform()},
        "session_id": SESSION_ID,
        "batch_id": f"{SESSION_ID}:{_seq}:{uuid.uuid4().hex[:8]}",
        "started_at": _iso(started_at),
        "ended_at": _iso(ended_at),
        "events": events,
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
