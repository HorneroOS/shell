"""Idle-cost guard (shell#651): nothing in an idle path may run unbounded.

Signal mode idled at several times Everyday's CPU because every telemetry
tick (2 Hz) also spawned `sensors`, a GPU read and `lsblk`. These static
contracts keep that class of regression out; the measured side is
`scripts/perf-signal-deck.sh --max-cpu` (docs/PERF_BASELINE.md "Idle
budget"), which needs a real compositor.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCAN = ("modules", "components", "services", "plugin/qml")

# Repeating Timers shorter than this must be gated by a `running:` binding.
SUB_SECOND_MS = 1000


def _qml_files():
    for top in SCAN:
        yield from sorted((ROOT / top).rglob("*.qml"))


def _blocks(src: str, kind: str):
    """Yield the body of every `kind { ... }` block (balanced braces)."""
    for m in re.finditer(rf"\b{kind}\s*\{{", src):
        depth, i = 1, m.end()
        while depth and i < len(src):
            depth += (src[i] == "{") - (src[i] == "}")
            i += 1
        yield src[m.end() : i - 1]


def _direct(body: str, prop: str):
    flat = body
    while True:  # drop nested blocks so only the block's own properties remain
        nxt = re.sub(r"\{[^{}]*\}", "", flat)
        if nxt == flat:
            break
        flat = nxt
    m = re.search(rf"\b{prop}:\s*([^\n;]+)", flat)
    return m.group(1).strip() if m else None


def test_no_always_running_subsecond_timer():
    offenders = []
    for path in _qml_files():
        for body in _blocks(path.read_text(encoding="utf-8"), "Timer"):
            if _direct(body, "repeat") != "true":
                continue
            interval = _direct(body, "interval") or ""
            running = _direct(body, "running")
            literal = re.fullmatch(r"\d+", interval)
            sub_second = (not literal) or int(interval) < SUB_SECOND_MS
            if sub_second and running == "true":
                offenders.append(f"{path.relative_to(ROOT)}: interval {interval}")
    assert not offenders, "repeating sub-second Timer with `running: true`:\n" + "\n".join(offenders)


def test_infinite_animations_are_gated():
    offenders = []
    for path in _qml_files():
        src = path.read_text(encoding="utf-8")
        for kind in ("NumberAnimation", "SequentialAnimation", "ParallelAnimation", "ColorAnimation", "RotationAnimation"):
            for body in _blocks(src, kind):
                if "Animation.Infinite" not in body:
                    continue
                running = _direct(body, "running")
                if running in (None, "true"):
                    offenders.append(f"{path.relative_to(ROOT)}: {kind}")
    assert not offenders, "Animation.Infinite without a running gate:\n" + "\n".join(offenders)


def test_system_usage_probes_run_on_their_own_budget():
    src = (ROOT / "services/SystemUsage.qml").read_text(encoding="utf-8")
    timers = list(_blocks(src, "Timer"))
    assert len(timers) == 1
    handler = timers[0]
    # The cheap reads follow the cadence; every process-spawning probe sits
    # behind a `due()` check, never directly in the per-tick handler.
    for probe in ("gpuUsage", "sensors", "storage"):
        needle = f"{probe}.running = true"
        assert needle in handler, probe
        before = handler[: handler.index(needle)]
        gate = before.rfind("if (root.due(")
        assert gate >= 0 and "}" not in before[gate:], f"{probe} must be started under `if (root.due(...))`"
    assert "Config.dashboard.sensorUpdateInterval" in src
    assert "Config.dashboard.diskUpdateInterval" in src


def test_probe_budgets_are_user_settings_with_sane_defaults():
    cfg = (ROOT / "config/DashboardConfig.qml").read_text(encoding="utf-8")
    assert "property int sensorUpdateInterval: 2000" in cfg
    assert "property int diskUpdateInterval: 30000" in cfg
    pane = (ROOT / "modules/controlcenter/dashboard/DashboardPane.qml").read_text(encoding="utf-8")
    assert "Config.dashboard.sensorUpdateInterval = root.sensorInterval" in pane
    assert "Config.dashboard.diskUpdateInterval = root.diskInterval" in pane
    # The pane used to write a key that does not exist (`updateInterval`).
    assert "Config.dashboard.updateInterval" not in pane


def test_perf_script_has_a_budget_gate():
    script = (ROOT / "scripts/perf-signal-deck.sh").read_text(encoding="utf-8")
    assert "--max-cpu" in script and "budget FAILED" in script
