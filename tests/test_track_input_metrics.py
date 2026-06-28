from __future__ import annotations

import importlib.util
import sys
import types
from pathlib import Path


def _load_tracker():
    keyboard = types.SimpleNamespace(
        Key=types.SimpleNamespace(
            ctrl_l="ctrl_l",
            ctrl_r="ctrl_r",
            shift="shift",
            shift_r="shift_r",
            backspace="backspace",
            delete="delete",
            space="space",
        ),
        Listener=lambda **_: None,
    )
    mouse = types.SimpleNamespace(Listener=lambda **_: None)
    sys.modules.setdefault("pynput", types.SimpleNamespace(keyboard=keyboard, mouse=mouse))
    script = Path(__file__).resolve().parents[1] / "scripts" / "track-input.py"
    spec = importlib.util.spec_from_file_location("track_input", script)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


def test_activity_records_focus_recovery_rest_gaps_and_spool_backlog(tmp_path, monkeypatch):
    tracker = _load_tracker()
    clock = {"now": 1000.0}
    focus = {"value": ("browser", "hash-a", "Firefox")}

    monkeypatch.setattr(tracker.time, "monotonic", lambda: clock["now"])
    monkeypatch.setattr(tracker, "_foreground_window", lambda: focus["value"])
    monkeypatch.setattr(tracker, "SPOOL_DIR", tmp_path)

    tracker._last_activity_time = 990.0
    tracker._active_block_started_time = 990.0
    tracker._focus_initialized = False
    tracker._last_focus_check_time = 0.0

    tracker._touch_activity()
    assert tracker._acc["context_switches"] == 0

    clock["now"] = 1015.0
    focus["value"] = ("development", "hash-b", "PowerShell")
    tracker._last_focus_check_time = 0.0
    tracker._touch_activity()

    assert tracker._acc["context_switches"] == 1
    assert tracker._acc["switch_recovery_seconds_total"] == 15.0
    assert tracker._acc["switch_recovery_samples"] == 1
    assert tracker._acc["focus_streak_samples"] == 1

    clock["now"] = 1400.0
    tracker._touch_activity()

    assert tracker._acc["rest_blocks"] == 1
    assert tracker._acc["active_starts_after_rest"] == 1
    assert tracker._acc["rest_gap_seconds_total"] == 385.0
    assert tracker._acc["rest_gap_seconds_max"] == 385.0

    (tmp_path / "pending.jsonl").write_text("{}\n{}\n", encoding="utf-8")
    snap = tracker._snapshot()

    assert snap["longest_focus_streak_seconds"] > 0
    assert snap["longest_active_block_seconds"] > 0
    assert snap["spool_backlog_batches"] == 2
    assert snap["spool_backlog_bytes"] > 0
