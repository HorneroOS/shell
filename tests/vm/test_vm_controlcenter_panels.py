"""Keep the remote screenshot matrix aligned with registered Settings panes."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
SCENARIO = ROOT / "tests/vm/scenarios/vm-controlcenter-panels.sh"
SMOKE = ROOT / "tests/vm/scenarios/vm-smoke.sh"
REGISTRY = ROOT / "modules/controlcenter/PaneRegistry.qml"


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

    assert len(scenario_panes) == 26
    assert scenario_panes == registered_panes


def test_matrix_uses_the_isolated_vm_and_checks_every_capture() -> None:
    script = SCENARIO.read_text(encoding="utf-8")
    smoke = SMOKE.read_text(encoding="utf-8")
    capture = (ROOT / "tests/vm/lib/controlcenter-capture.sh").read_text(encoding="utf-8")

    assert 'bash "$VM_DIR/scenarios/vm-smoke.sh"' in script
    assert 'if ! bash "$VM_DIR/scenarios/vm-smoke.sh"; then' in script
    assert 'assert_no_quickshell_crash "initial smoke"' in script
    assert 'assert_no_quickshell_crash "$pane"' in script
    assert ".cache/quickshell/crashes" in script and "-name report.txt" in script
    assert 'echo "==> checking Terminal settings CLI contract"' in smoke
    assert 'timeout 15s horneroctl --json config default-apps list' in smoke
    assert "'.ok == true and (.data.terminals_available | type == \"string\")'" in smoke
    assert 'baseline_image="$SCREENSHOT_DIR/$pane-before.png"' in script
    assert 'qemu-screenshot.sh" "$baseline_image"' in script
    assert 'vm_capture_controlcenter_content "$remote_image" "$image" "$baseline_image"' in script
    assert 'vm_ssh "$(vm_hypr_env)\ntimeout 5 grim' in capture
    assert script.count("VM_SSH_TIMEOUT=30s vm_ssh") == 3
    assert 'vm_capture_controlcenter_content /tmp/vm-controlcenter-terminal.png \\' in smoke
    assert 'sleep 2' in (ROOT / "tests/vm/lib/controlcenter-capture.sh").read_text()
    assert '"${BASELINE_SCREENSHOT}"; then' in smoke
    assert 'BASELINE_SCREENSHOT="${SCREENSHOT_DIR}/desktop-before-settings.png"' in smoke
    assert 'python3 "$VM_LIB_DIR/check_screenshot.py" "$image" --quiet' in capture
    assert '--region 200,80,1030,600 --different-from "$baseline"' in capture
    assert '--min-diff-ratio 0.05 --quiet "$image"' in capture
    assert 'local max_attempts=10' in capture
    assert 'sleep 0.5' in capture
    assert 'grim did not answer; falling back to the QEMU framebuffer' in capture
    assert 'logs/controlcenter-failure.log' in script
    assert '--region 200,80,1030,600' in capture
    assert 'hyprctl -j activewindow' in smoke
    assert 'timeout 2s hyprctl -j activewindow 2>/dev/null' in smoke
    assert 'qemu-screenshot.sh' in smoke
    assert 'failure.png' in smoke
    assert 'find /run/user/1000/hypr -maxdepth 2 -type f -name hyprland.log' in smoke
    assert 'tail -n 80 /tmp/hypr.log /tmp/qs.log' in smoke
    assert 'name log.qslog' in smoke
    assert 'Hyprland and Quickshell process snapshot' in smoke
    assert "coredumpctl --no-pager info" in smoke and "quickshell_pid" in smoke
    assert 'report.txt' in smoke
    assert 'export PATH=\\$HOME/.local/bin:\\$PATH' in (ROOT / "tests/vm/lib/start-session.sh").read_text()
    assert 'timeout 2s hyprctl -j activewindow 2>/dev/null' in script
    assert '.mapped == true' in script
    assert 'write_result PASS ""' in script
    assert "controlCenter close" in script
    assert '.floating == true and .size[0] >= 1100 and .size[1] >= 600' in script
    assert "sleep 2" not in script
    assert '[[ "$captured_count" -eq 26 ]]' in script
    assert 'last-json-object.py' in smoke
    assert 'WELCOME_STATUS_RAW=' in smoke
    assert 'Welcome status IPC did not return a JSON object' in smoke

    provision = (ROOT / "tests/vm/lib/provision.sh").read_text(encoding="utf-8")
    assert "networkmanager bluez" in provision
    assert "unmanaged-devices=interface-name:eth0" in provision
    assert "systemctl enable --now NetworkManager bluetooth" in provision

    loop = script.split("done <<'PANE_LIST'", maxsplit=1)[0]
    assert 'controlCenter close' not in loop
    assert script.count('controlCenter close') == 1
    assert 'assert_no_quickshell_crash "panel matrix"' in script


def test_vm_settings_window_rule_matches_factory_layout() -> None:
    guest_config = (ROOT / "tests/vm/guest/hyprland.conf").read_text(encoding="utf-8")
    for snippet in (
        "match:class = ^org[.]quickshell$",
        "match:title = ^Hornero Settings.*$",
        "float = true",
        "center = true",
    ):
        assert snippet in guest_config


def test_smoke_failure_artifact_includes_process_and_quickshell_diagnostics() -> None:
    script = SMOKE.read_text(encoding="utf-8")

    assert 'logs/vm-smoke-failure.log' in script
    assert "graphical failure process snapshot" in script
    assert "pgrep -af 'horneroctl|qs|quickshell|Hyprland'" in script
    assert "/run/user/1000/quickshell/by-id/*/log.qslog" in script
    assert "VM_SSH_TIMEOUT=30s vm_ssh" in script


def test_smoke_closes_and_verifies_welcome_before_control_center_capture() -> None:
    script = SMOKE.read_text(encoding="utf-8")

    welcome_close = script.index("ipc call welcome close")
    welcome_status = script.index("ipc call welcome status")
    terminal_settings = script.index("ipc call controlCenter open terminal")
    assert welcome_close < welcome_status < terminal_settings
    assert "jq -e '.open == false'" in script
