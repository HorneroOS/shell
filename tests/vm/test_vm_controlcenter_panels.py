"""Keep the remote screenshot matrix aligned with registered Settings panes."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
SCENARIO = ROOT / "tests/vm/scenarios/vm-controlcenter-panels.sh"
REGISTRY = ROOT / "modules/controlcenter/PaneRegistry.qml"
SMOKE = ROOT / "tests/vm/scenarios/vm-smoke.sh"


def test_control_center_matrix_covers_every_registered_destination() -> None:
    script = SCENARIO.read_text(encoding="utf-8")
    pane_list = script.split("done <<'PANE_LIST'", maxsplit=1)[1].split(
        "\nPANE_LIST", maxsplit=1
    )[0]
    scenario_panes = [
        tuple(line.split("|", maxsplit=1))
        for line in pane_list.splitlines()
        if line.strip()
    ]

    registry = REGISTRY.read_text(encoding="utf-8")
    pane_catalogue = registry.split(
        "readonly property list<QtObject> panes: [", maxsplit=1
    )[1].split("readonly property list<QtObject> searchTargets:", maxsplit=1)[0]
    registered_panes = [
        (match.group(1), match.group(2) or match.group(3))
        for match in re.finditer(
            r'readonly property string id:\s*"([^"]+)".*?'
            r'readonly property string title:\s*(?:qsTr\("([^"]+)"\)|"([^"]+)")',
            pane_catalogue,
            re.DOTALL,
        )
    ]

    assert len(scenario_panes) == 25
    assert scenario_panes == registered_panes


def test_matrix_uses_the_isolated_vm_and_checks_every_capture() -> None:
    script = SCENARIO.read_text(encoding="utf-8")

    assert 'bash "$VM_DIR/scenarios/vm-smoke.sh"' in script
    assert 'python3 "$VM_LIB_DIR/check_screenshot.py" "$image"' in script
    assert 'hyprctl -j activewindow' in script
    assert 'write_result PASS ""' in script
    assert "controlCenter close" in script


def test_smoke_failure_artifact_includes_process_and_quickshell_diagnostics() -> None:
    script = SMOKE.read_text(encoding="utf-8")

    assert 'logs/vm-smoke-failure.log' in script
    assert "graphical failure process snapshot" in script
    assert "pgrep -af 'horneroctl|qs|quickshell|Hyprland'" in script
    assert "/run/user/1000/quickshell/by-id/*/log.qslog" in script
