"""Perf baseline harness: the script is runnable, honest, and documented.

Static contract tests (no compositor needed): the harness contract is
asserted structurally so regressions fail here, not on a live machine.
"""
import os
import json
import subprocess
import textwrap
from tempfile import TemporaryDirectory
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "perf-baseline.sh"
DOC = ROOT / "docs" / "PERF_BASELINE.md"


def test_harness_exists_and_runs():
    assert SCRIPT.exists(), "missing scripts/perf-baseline.sh"
    assert os.access(SCRIPT, os.X_OK), "harness must be executable"


def test_harness_is_safe_shell():
    text = SCRIPT.read_text()
    assert "set -euo pipefail" in text
    assert "--restart" in text, "startup timing must stay opt-in"
    assert "restart --yes" in text or "shell restart" in text


def test_harness_probes_named_metrics():
    text = SCRIPT.read_text()
    for probe in ("smaps_rollup", "ipc call", "hyprctl layers",
                  "quickshell --version", "startup_ready_ms",
                  "rss_kb", "pss_kb", "pss_anon_kb", "pss_file_kb",
                  "pss_shmem_kb", "cpu_percent", "ipc_ms"):
        assert probe in text, f"harness missing probe {probe}"


def test_harness_finds_shell_by_either_process_name():
    # The shell runs as `quickshell` (distro binary) or `qs` (wrapper entry
    # point, e.g. the QA guest): both PID resolutions must share one lookup
    # that covers both, preferring the daemon over transient qs ipc clients.
    text = SCRIPT.read_text()
    assert "shell_pid() {" in text
    assert "pgrep -x quickshell" in text
    assert "pgrep -x -o qs" in text
    assert text.count('PID="$(shell_pid)"') == 2, "startup + post-restart must share shell_pid"
    assert "qs --version" in text, "version probe needs the qs fallback too"


def test_harness_recovers_config_path_from_live_process_arguments():
    _, report = _run_fixture(
        "hyprland",
        shell_pid="4242",
        process_config="argv",
        clear_config_environment=True,
    )
    assert report is not None
    assert report["qml_files_available"] == 3


def test_harness_recovers_equals_form_config_path_argument():
    _, report = _run_fixture(
        "hyprland",
        shell_pid="4242",
        process_config="argv_equals",
        clear_config_environment=True,
    )
    assert report is not None
    assert report["qml_files_available"] == 3


def test_harness_recovers_config_path_from_live_process_environment():
    _, report = _run_fixture(
        "hyprland",
        shell_pid="4242",
        process_config="environment",
        clear_config_environment=True,
    )
    assert report is not None
    assert report["qml_files_available"] == 3


def test_methodology_and_reference_capture_documented():
    assert DOC.exists(), "missing docs/PERF_BASELINE.md"
    text = DOC.read_text()
    for section in ("## What is measured", "## How to run",
                    "## How to compare", "## Reference captures and rules"):
        assert section in text, f"doc missing {section}"
    assert "never publish estimates" in text.lower()
    assert "first rendered" in text.lower()


def test_sanitized_reference_capture_has_observed_values_and_limits():
    capture = ROOT / "docs" / "perf-baselines" / "2026-10-12.md"
    assert capture.exists(), "missing dated reference capture"
    text = capture.read_text()
    for expected in (
        "Quickshell: `0.3.1`",
        "Compositor: Hyprland",
        "| **Median** | **892.5** | **556.4** | **0.00** | **23** | **7** |",
        "not a clean-session or cold-start measurement",
        "does not measure greeter-to-desktop time",
        "full timestamps are omitted",
    ):
        assert expected in text, f"reference capture missing {expected!r}"


def test_follow_up_capture_is_separate_sanitized_and_honest_about_limits():
    capture = ROOT / "docs" / "perf-baselines" / "2026-10-12.md"
    text = capture.read_text()
    for expected in (
        "## Follow-up host observation",
        "`hornero-shell 1.2.7-1`",
        "| **Median** | **517.4** | **431.4** | **342.4** | **88.9** | **0.0** | **0.00** | **23** | **7** |",
        "do not infer a\nbefore/after improvement",
        "does not supply the clean-session",
        "Host identity, process IDs, host memory, CPU topology, user name",
    ):
        assert expected in text, f"follow-up capture missing {expected!r}"


def _write_executable(path: Path, text: str) -> None:
    path.write_text(textwrap.dedent(text), encoding="utf-8")
    path.chmod(0o755)


def _run_fixture(
    compositor: str,
    output_format: str | None = "json",
    niri_outputs: str = '{"HDMI-A-1":{"current_mode":{"width":1920}},"eDP-1":{"current_mode":null}}',
    niri_layers: str = '[{"namespace":"hornero"}]',
    shell_pid: str | None = None,
    proc_root: Path | None = None,
    process_config: str | None = None,
    clear_config_environment: bool = False,
) -> tuple[str, dict | None]:
    with TemporaryDirectory(prefix="hornero-perf-") as temporary:
        root = Path(temporary)
        bindir = root / "bin"
        qml_root = root / "shell"
        bindir.mkdir()
        qml_root.mkdir()
        (qml_root / "shell.qml").write_text("// fixture\n", encoding="utf-8")
        (qml_root / "modules").mkdir()
        (qml_root / "modules" / "Loaded.qml").write_text("// fixture\n", encoding="utf-8")
        (qml_root / "modules" / "AvailableOnly.qml").write_text("// fixture\n", encoding="utf-8")
        fixture_proc_root = proc_root
        if process_config is not None:
            fixture_proc_root = root / "proc"
            process_dir = fixture_proc_root / (shell_pid or str(os.getpid()))
            process_dir.mkdir(parents=True)
            config_path = str(qml_root / "shell.qml")
            if process_config == "argv":
                (process_dir / "cmdline").write_bytes(
                    b"/usr/bin/quickshell\0--path\0" + config_path.encode() + b"\0"
                )
            elif process_config == "argv_equals":
                (process_dir / "cmdline").write_bytes(
                    b"/usr/bin/quickshell\0--path=" + config_path.encode() + b"\0"
                )
            elif process_config == "environment":
                (process_dir / "environ").write_bytes(
                    b"QS_CONFIG_PATH=" + config_path.encode() + b"\0"
                )
            else:
                raise ValueError(f"unsupported process_config fixture: {process_config}")
        _write_executable(
            bindir / "pgrep",
            """
            #!/bin/sh
            printf '%s\\n' "$HORNERO_TEST_PID"
            """,
        )
        _write_executable(
            bindir / "quickshell",
            """
            #!/bin/sh
            printf 'Quickshell fixture 1.0\\n'
            """,
        )
        _write_executable(
            bindir / "qs",
            """
            #!/bin/sh
            if [ "$1" = ipc ]; then
                printf 'false\\n'
            else
                printf 'Quickshell fixture 1.0\\n'
            fi
            """,
        )

        env = os.environ.copy()
        env.update(
            {
                "PATH": f"{bindir}:{env['PATH']}",
                "HORNERO_TEST_PID": shell_pid or str(os.getpid()),
                "QS_CONFIG_PATH": "" if clear_config_environment else str(qml_root / "shell.qml"),
                "QS_CONFIG_NAME": "",
                "QS_MANIFEST": "",
                "QS_PLUGIN_PATH": "",
                "NIRI_SOCKET": "/fixture/niri.sock" if compositor == "niri" else "",
                "HYPRLAND_INSTANCE_SIGNATURE": "fixture" if compositor == "hyprland" else "",
                "NIRI_TEST_OUTPUTS": niri_outputs,
                "NIRI_TEST_LAYERS": niri_layers,
            }
        )
        if fixture_proc_root is not None:
            env["HORNERO_PROC_ROOT"] = str(fixture_proc_root)
        if compositor == "niri":
            _write_executable(
                bindir / "niri",
                """
                #!/bin/sh
                case "$*" in
                    *outputs*) printf '%s\\n' "$NIRI_TEST_OUTPUTS" ;;
                    *layers*) printf '%s\\n' "$NIRI_TEST_LAYERS" ;;
                    *) exit 2 ;;
                esac
                """,
            )
        else:
            _write_executable(
                bindir / "hyprctl",
                """
                #!/bin/sh
                case "$*" in
                    *monitors*) printf 'Monitor HDMI-A-1\\nMonitor DP-1\\n' ;;
                    *layers*) printf 'namespace: hornero\\nnamespace: wallpaper\\n' ;;
                    *) exit 2 ;;
                esac
                """,
            )
        if shell_pid is not None:
            _write_executable(
                bindir / "ps",
                """
                #!/bin/sh
                case "$*" in
                    *rss*) printf '1234\\n' ;;
                    *etimes*) printf '10\\n' ;;
                    *) exit 2 ;;
                esac
                """,
            )

        args = [str(SCRIPT), "--samples", "1", "--interval", "0"]
        if output_format is not None:
            args += ["--format", output_format]
        report = subprocess.run(
            args,
            check=False,
            capture_output=True,
            text=True,
            env=env,
            timeout=8,
        )
        assert report.returncode == 0, report.stderr
        return report.stdout, json.loads(report.stdout) if output_format == "json" else None


def test_harness_uses_niri_json_for_monitor_and_layer_counts():
    _, report = _run_fixture("niri")
    assert report is not None
    assert report["compositor"] == "niri"
    assert report["monitors"] == 1
    assert report["samples"][0]["layers"] == 1
    _assert_memory_breakdown(report["samples"][0])
    assert 0 <= report["samples"][0]["cpu_percent"]
    assert report["qml_files_available"] == 3
    assert "qml_files_live" not in report


def test_harness_keeps_hyprland_metrics():
    _, report = _run_fixture("hyprland")
    assert report is not None
    assert report["compositor"] == "hyprland"
    assert report["monitors"] == 2
    assert report["samples"][0]["layers"] == 2
    _assert_memory_breakdown(report["samples"][0])
    assert 0 <= report["samples"][0]["cpu_percent"]


def test_harness_reports_niri_errors_and_unknown_shapes_as_unavailable():
    _, report = _run_fixture(
        "niri",
        niri_outputs='{"Err":"unsupported request"}',
        niri_layers='{"unexpected":"shape"}',
    )
    assert report is not None
    assert report["monitors"] is None
    assert report["samples"][0]["layers"] is None


def test_harness_reports_null_memory_breakdown_when_smaps_rollup_is_unreadable():
    _, report = _run_fixture("niri", shell_pid="999999999", proc_root=Path("/nonexistent"))
    assert report is not None
    assert report["samples"][0]["memory_breakdown"] == {
        "pss_anon_kb": None,
        "pss_file_kb": None,
        "pss_shmem_kb": None,
    }


def test_harness_reports_null_for_missing_pss_breakdown_fields():
    with TemporaryDirectory(prefix="hornero-proc-") as temporary:
        proc_root = Path(temporary)
        rollup = proc_root / "999999999" / "smaps_rollup"
        rollup.parent.mkdir()
        rollup.write_text("Rss: 10 kB\nPss: 5 kB\n", encoding="utf-8")
        _, report = _run_fixture("niri", shell_pid="999999999", proc_root=proc_root)
    assert report is not None
    assert report["samples"][0]["memory_breakdown"] == {
        "pss_anon_kb": None,
        "pss_file_kb": None,
        "pss_shmem_kb": None,
    }


def test_harness_parses_available_pss_breakdown_fields():
    with TemporaryDirectory(prefix="hornero-proc-") as temporary:
        proc_root = Path(temporary)
        rollup = proc_root / "999999999" / "smaps_rollup"
        rollup.parent.mkdir()
        rollup.write_text(
            "Pss: 60 kB\nPss_Anon: 10 kB\nPss_File: 20 kB\nPss_Shmem: 30 kB\n",
            encoding="utf-8",
        )
        _, report = _run_fixture("niri", shell_pid="999999999", proc_root=proc_root)
    assert report is not None
    assert report["samples"][0]["memory_breakdown"] == {
        "pss_anon_kb": 10,
        "pss_file_kb": 20,
        "pss_shmem_kb": 30,
    }


def _assert_memory_breakdown(sample: dict) -> None:
    memory = sample["memory_breakdown"]
    assert set(memory) == {"pss_anon_kb", "pss_file_kb", "pss_shmem_kb"}
    assert all(value is None or isinstance(value, int) for value in memory.values())


def test_harness_prints_a_complete_human_table_by_default():
    output, report = _run_fixture("hyprland", output_format=None)
    assert report is None
    assert "Sample  RSS MiB  PSS MiB  Anon MiB  File MiB  Shared MiB" in output
    assert "CPU cores:" in output
    assert "QML files available: 3" in output
