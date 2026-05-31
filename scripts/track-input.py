#!/usr/bin/env python3
"""
VaultWares Daily Input Tracker
================================
Runs silently in the background (via Windows scheduled task).
Tracks raw input signals and writes hourly stats to:
  agent-ledger/input-logs/YYYY-MM-DD.json

Requires: pynput, pyperclip
Install:  pip install pynput pyperclip
"""

import json
import math
import os
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

# Optional clipboard support
try:
    import pyperclip
    HAS_CLIPBOARD = True
except ImportError:
    HAS_CLIPBOARD = False

try:
    from pynput import keyboard, mouse
except ImportError:
    sys.exit("pynput not found. Run: pip install pynput")

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
SCRIPT_DIR   = Path(__file__).parent.resolve()
LOG_DIR      = SCRIPT_DIR.parent / "input-logs"
FLUSH_EVERY  = 60          # seconds between JSON flushes
SCREEN_DPI   = 96          # standard Windows DPI — adjust if HiDPI
PX_PER_METER = SCREEN_DPI / 0.0254   # ≈ 3779.5 px / m

# ---------------------------------------------------------------------------
# Per-minute accumulator (reset on every flush)
# ---------------------------------------------------------------------------
_lock = threading.Lock()
_acc = {
    "keystrokes":      0,
    "chars_typed":     0,
    "saves":           0,
    "copies":          0,
    "pastes":          0,
    "chars_pasted":    0,
    "mouse_px":        0.0,
}
_mouse_last = None   # (x, y) of previous position
_ctrl_held  = False  # True while any Ctrl key is pressed
_shift_held = False  # True while any Shift key is pressed

# ---------------------------------------------------------------------------
# JSON helpers
# ---------------------------------------------------------------------------

def _log_path(dt: datetime) -> Path:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    return LOG_DIR / f"{dt.strftime('%Y-%m-%d')}.json"


def _blank_day(dt: datetime) -> dict:
    return {
        "schemaVersion": 1,
        "date": dt.strftime("%Y-%m-%d"),
        "hourly": [
            {
                "hour":            h,
                "keystrokes":      0,
                "chars_typed":     0,
                "mouse_distance_m": 0.0,
                "saves":           0,
                "copies":          0,
                "pastes":          0,
                "chars_pasted":    0,
            }
            for h in range(24)
        ],
    }


def _load_day(dt: datetime) -> dict:
    p = _log_path(dt)
    if p.exists():
        try:
            return json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            pass
    return _blank_day(dt)


def _save_day(dt: datetime, data: dict) -> None:
    p   = _log_path(dt)
    tmp = str(p) + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    os.replace(tmp, str(p))

# ---------------------------------------------------------------------------
# Flush loop — runs every FLUSH_EVERY seconds
# ---------------------------------------------------------------------------

def _flush() -> None:
    global _mouse_last

    now  = datetime.now()
    hour = now.hour

    with _lock:
        snap = dict(_acc)
        for k in _acc:
            _acc[k] = 0.0 if isinstance(_acc[k], float) else 0

    # Skip writing if absolutely nothing happened
    if snap["keystrokes"] == 0 and snap["mouse_px"] == 0.0:
        return

    day  = _load_day(now)
    slot = day["hourly"][hour]

    slot["keystrokes"]       += snap["keystrokes"]
    slot["chars_typed"]      += snap["chars_typed"]
    slot["saves"]            += snap["saves"]
    slot["copies"]           += snap["copies"]
    slot["pastes"]           += snap["pastes"]
    slot["chars_pasted"]     += snap["chars_pasted"]
    slot["mouse_distance_m"] += round(snap["mouse_px"] / PX_PER_METER, 4)

    _save_day(now, day)


def _flush_loop() -> None:
    while True:
        time.sleep(FLUSH_EVERY)
        try:
            _flush()
        except Exception:
            pass   # never crash the daemon thread

# ---------------------------------------------------------------------------
# Keyboard listener
# ---------------------------------------------------------------------------
_CTRL_KEYS  = {keyboard.Key.ctrl_l, keyboard.Key.ctrl_r}
_SHIFT_KEYS = {keyboard.Key.shift, keyboard.Key.shift_r}


def _on_press(key) -> None:
    global _ctrl_held, _shift_held

    with _lock:
        _acc["keystrokes"] += 1

        if key in _CTRL_KEYS:
            _ctrl_held = True
            return
        if key in _SHIFT_KEYS:
            _shift_held = True
            return

        # --- Ctrl combo handling ---
        if _ctrl_held:
            try:
                ch = key.char.lower() if hasattr(key, "char") and key.char else None
            except Exception:
                ch = None

            if ch == "s":
                _acc["saves"] += 1
            elif ch == "c":
                _acc["copies"] += 1
            elif ch == "v":
                _acc["pastes"] += 1
                if HAS_CLIPBOARD:
                    try:
                        text = pyperclip.paste() or ""
                        _acc["chars_pasted"] += len(text)
                    except Exception:
                        pass
            return

        # --- Printable char accounting ---
        try:
            if hasattr(key, "char") and key.char and len(key.char) == 1:
                _acc["chars_typed"] += 1
        except Exception:
            pass

        if key == keyboard.Key.space:
            _acc["chars_typed"] += 1


def _on_release(key) -> None:
    global _ctrl_held, _shift_held
    with _lock:
        if key in _CTRL_KEYS:
            _ctrl_held = False
        if key in _SHIFT_KEYS:
            _shift_held = False

# ---------------------------------------------------------------------------
# Mouse listener
# ---------------------------------------------------------------------------

def _on_move(x: int, y: int) -> None:
    global _mouse_last
    with _lock:
        if _mouse_last is not None:
            dx = x - _mouse_last[0]
            dy = y - _mouse_last[1]
            _acc["mouse_px"] += math.sqrt(dx * dx + dy * dy)
        _mouse_last = (x, y)

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    # Flush thread
    t = threading.Thread(target=_flush_loop, daemon=True)
    t.start()

    # Listeners
    kb = keyboard.Listener(on_press=_on_press, on_release=_on_release)
    ms = mouse.Listener(on_move=_on_move)

    kb.start()
    ms.start()

    kb.join()   # blocks until listener stops (never under normal operation)


if __name__ == "__main__":
    main()
