"""Unit tests for Polkit requester ancestry attribution (scripts/polkit_requester.py)."""

from __future__ import annotations

import json
from pathlib import Path
import sys

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

import polkit_requester as pr  # noqa: E402


def _make_proc(
    proc_root: Path,
    pid: int,
    comm: str,
    ppid: int,
    cmdline: list[str] | None = None,
) -> None:
    """Create a synthetic /proc/<pid>/{stat,cmdline} entry."""
    pid_dir = proc_root / str(pid)
    pid_dir.mkdir(parents=True, exist_ok=True)
    # Standard Linux /proc/<pid>/stat format: pid (comm) state ppid ...
    (pid_dir / "stat").write_text(f"{pid} ({comm}) S {ppid} 1 1 0 -1 4194304\n", encoding="utf-8")
    if cmdline is not None:
        (pid_dir / "cmdline").write_bytes(b"\x00".join(arg.encode("utf-8") for arg in cmdline) + b"\x00")


@pytest.mark.parametrize(
    ("agent_key", "expected_label", "cmdline"),
    [
        ("claude", "Claude Code", ["node", "/usr/local/bin/claude", "--dangerously-skip-permissions"]),
        ("gemini", "Gemini CLI", ["node", "/usr/bin/gemini"]),
        ("codex", "Codex", ["codex", "exec"]),
        ("hermes", "Hermes", ["python3", "/opt/hermes/hermes.py"]),
        ("aider", "Aider", ["python3", "/usr/bin/aider", "--model", "sonnet"]),
        ("opencode", "OpenCode", ["opencode"]),
        ("hornero-assistant", "Hornero Assistant", ["python3", "/usr/lib/hornero/hornero-assistant.py"]),
    ],
)
def test_detects_all_known_coding_agents_in_ancestry(
    tmp_path: Path,
    agent_key: str,
    expected_label: str,
    cmdline: list[str],
):
    # init(1) -> agent(100) -> bash(200) -> pkexec(300)
    _make_proc(tmp_path, 100, Path(cmdline[0]).name, 1, cmdline)
    _make_proc(tmp_path, 200, "bash", 100, ["bash", "-c", "pkexec pacman -Syu"])
    _make_proc(tmp_path, 300, "pkexec", 200, ["pkexec", "/usr/bin/pacman", "-Syu"])

    result = pr.resolve_requester(
        300,
        action_id="org.freedesktop.policykit.exec",
        proc_root=tmp_path,
    )

    assert result["is_agent"] is True
    assert result["agent_name"] == agent_key
    assert result["agent_label"] == expected_label
    assert result["label"] == expected_label
    assert "Coding agent" in result["detail"]
    assert "pacman" in result["detail"]
    assert "PID 300" in result["detail"]
    assert result["is_storage"] is False
    assert result["pid"] == 300
    assert result["ancestry"] == ["pkexec", "bash", Path(cmdline[0]).name]


def test_detects_storage_drive_unlock_from_udisksd_process(tmp_path: Path):
    _make_proc(tmp_path, 500, "udisksd", 1, ["/usr/lib/udisks2/udisksd"])

    result = pr.resolve_requester(
        500,
        action_id="org.freedesktop.udisks2.encrypted-unlock",
        proc_root=tmp_path,
    )

    assert result["is_agent"] is False
    assert result["agent_name"] is None
    assert result["is_storage"] is True
    assert result["label"] == "Drive unlock (udisks2)"
    assert "org.freedesktop.udisks2.encrypted-unlock" in result["detail"]
    assert "PID 500" in result["detail"]


def test_detects_storage_drive_unlock_from_action_id_without_pid(tmp_path: Path):
    result = pr.resolve_requester(
        None,
        action_id="org.freedesktop.udisks2.filesystem-mount-system",
        proc_root=tmp_path,
    )

    assert result["is_agent"] is False
    assert result["is_storage"] is True
    assert result["label"] == "Drive unlock (udisks2)"
    assert "org.freedesktop.udisks2.filesystem-mount-system" in result["detail"]


def test_agent_triggering_storage_unlock_marks_both(tmp_path: Path):
    _make_proc(tmp_path, 100, "claude", 1, ["claude"])
    _make_proc(tmp_path, 200, "udisksctl", 100, ["udisksctl", "unlock", "-b", "/dev/nvme0n1p2"])

    result = pr.resolve_requester(
        200,
        action_id="org.freedesktop.udisks2.encrypted-unlock",
        proc_root=tmp_path,
    )

    assert result["is_agent"] is True
    assert result["agent_name"] == "claude"
    assert result["is_storage"] is True
    assert result["label"] == "Claude Code · Drive unlock"


def test_regular_user_pkexec_without_agent(tmp_path: Path):
    _make_proc(tmp_path, 10, "kitty", 1, ["kitty"])
    _make_proc(tmp_path, 20, "zsh", 10, ["zsh"])
    _make_proc(tmp_path, 30, "pkexec", 20, ["pkexec", "--user", "root", "/usr/bin/gparted"])

    result = pr.resolve_requester(
        30,
        action_id="org.freedesktop.policykit.exec",
        proc_root=tmp_path,
    )

    assert result["is_agent"] is False
    assert result["agent_name"] is None
    assert result["is_storage"] is False
    assert result["label"] == "gparted"
    assert "via pkexec" in result["detail"]
    assert "PID 30" in result["detail"]


def test_stat_comm_with_spaces_and_parentheses(tmp_path: Path):
    _make_proc(tmp_path, 42, "Web Content (1)", 1, ["firefox"])
    _make_proc(tmp_path, 43, "pkexec", 42, ["pkexec", "/usr/bin/systemctl", "restart", "cups"])

    stat = pr.read_proc_stat(42, proc_root=tmp_path)
    assert stat == ("Web Content (1)", 1)

    result = pr.resolve_requester(43, proc_root=tmp_path)
    assert result["ancestry"] == ["pkexec", "Web Content (1)"]
    assert result["label"] == "systemctl"


def test_cycle_protection_in_walk_ancestry(tmp_path: Path):
    _make_proc(tmp_path, 10, "a", 20, ["a"])
    _make_proc(tmp_path, 20, "b", 10, ["b"])

    ancestry = pr.walk_ancestry(10, proc_root=tmp_path)
    assert [p["pid"] for p in ancestry] == [10, 20]


def test_auto_discovers_pkexec_pid_when_pid_omitted(tmp_path: Path):
    _make_proc(tmp_path, 100, "aider", 1, ["aider"])
    _make_proc(tmp_path, 200, "pkexec", 100, ["pkexec", "/usr/bin/pacman", "-S", "ripgrep"])

    result = pr.resolve_requester(
        None,
        action_id="org.freedesktop.policykit.exec",
        proc_root=tmp_path,
    )

    assert result["pid"] == 200
    assert result["is_agent"] is True
    assert result["agent_name"] == "aider"


def test_cli_outputs_valid_json(tmp_path: Path, capsys: pytest.CaptureFixture[str]):
    _make_proc(tmp_path, 77, "gemini", 1, ["gemini"])
    _make_proc(tmp_path, 88, "pkexec", 77, ["pkexec", "/usr/bin/pacman", "-Syu"])

    rc = pr.main(["--pid", "88", "--action-id", "org.freedesktop.policykit.exec", "--proc-root", str(tmp_path)])
    assert rc == 0

    payload = json.loads(capsys.readouterr().out)
    assert payload["is_agent"] is True
    assert payload["agent_name"] == "gemini"
    assert payload["label"] == "Gemini CLI"
