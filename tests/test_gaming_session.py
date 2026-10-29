"""Gaming session contract: the greeter-selectable Gamescope session is
explicitly experimental, fails closed without gamescope/Steam, and never
gains power/TDP/root privileges (docs/GAMING-SESSION.md, shell#336)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DESKTOP = ROOT / "assets" / "hornero-gaming-session.desktop"
WRAPPER = ROOT / "scripts" / "hornero-gaming-session.sh"


def test_session_entry_is_labelled_experimental():
    text = DESKTOP.read_text()
    assert "Experimental" in text
    assert "Exec=/usr/bin/hornero-gaming-session" in text
    assert "Type=Application" in text


def test_wrapper_fails_closed_without_gamescope_or_steam():
    text = WRAPPER.read_text()
    assert "command -v gamescope" in text
    assert "command -v steam" in text
    assert "exit 1" in text


def test_wrapper_launches_steam_gamepadui_under_gamescope():
    text = WRAPPER.read_text()
    assert "gamescope" in text
    assert "steam -gamepadui" in text
    assert 'exec "$@"' in text


def test_wrapper_has_no_privileged_or_power_controls():
    code = "\n".join(
        line for line in WRAPPER.read_text().splitlines() if not line.lstrip().startswith("#")
    )
    for forbidden in ("sudo", "pkexec", "ryzenadj", "tdp", "powercap"):
        assert forbidden not in code.lower(), f"wrapper must not touch {forbidden}"


def test_wrapper_is_installed_by_cmake():
    cmake = (ROOT / "CMakeLists.txt").read_text()
    assert "hornero-gaming-session.desktop" in cmake
    assert "share/wayland-sessions" in cmake
    assert "hornero-gaming-session.sh" in cmake
