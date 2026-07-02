from __future__ import annotations

import importlib.util
import sys
import types
from datetime import datetime, timezone
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


def test_idle_resume_records_natural_path_until_next_click(monkeypatch):
    tracker = _load_tracker()
    clock = {"now": 2000.0}

    monkeypatch.setattr(tracker.time, "monotonic", lambda: clock["now"])
    monkeypatch.setattr(tracker, "_foreground_window", lambda: ("development", "hash-dev", "PowerShell"))

    tracker._last_activity_time = 1960.0
    tracker._active_block_started_time = 1960.0
    tracker._last_focus_check_time = 0.0
    tracker._focus_initialized = True
    tracker._focus_category = "development"
    tracker._window_hash = "hash-dev"
    tracker._window_name = "PowerShell"
    tracker._mouse_last = None

    tracker._on_move(10, 10)
    clock["now"] = 2000.2
    tracker._on_press(types.SimpleNamespace(char="x"))
    clock["now"] = 2000.4
    tracker._on_move(30, 40)
    clock["now"] = 2000.6
    tracker._on_click(30, 40, "left", True)

    snap = tracker._snapshot()
    natural_paths = snap["natural_paths"]

    assert len(natural_paths) == 1
    path = natural_paths[0]
    assert path["trigger"] == "idle_resume"
    assert path["stats"]["point_count"] == 2
    assert path["stats"]["key_count"] == 1
    assert path["key_presses"][0]["value"] == "x"
    assert path["mouse_path"][0]["x"] == 10
    assert path["click_target"]["x"] == 30

    batch = tracker._build_batch(
        datetime(2026, 7, 2, 13, 0, tzinfo=timezone.utc),
        datetime(2026, 7, 2, 13, 1, tzinfo=timezone.utc),
        snap,
    )

    assert batch is not None
    assert [event["event_type"] for event in batch["events"]] == ["minute_rollup", "natural_path"]
    natural_event = batch["events"][1]
    assert natural_event["metrics"]["key_presses"][0]["value"] == "x"
    assert natural_event["dimensions"]["privacy_level"] == "raw_keys_owner_opt_in"
