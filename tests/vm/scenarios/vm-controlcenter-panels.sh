#!/usr/bin/env bash
# Remote/manual visual matrix for every Control Center destination.
set -euo pipefail
VM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VM_LIB_DIR="$VM_ROOT/lib"
# shellcheck source=tests/vm/lib/env.sh
# shellcheck disable=SC1091
source "$VM_LIB_DIR/env.sh"
# shellcheck source=tests/vm/lib/controlcenter-capture.sh
# shellcheck disable=SC1091
source "$VM_LIB_DIR/controlcenter-capture.sh"
arg="${1-}"
if [[ "$arg" == "--help" ]]; then
    echo "usage: vm-controlcenter-panels.sh [--dry-run]"
    exit 0
fi
if [[ "$arg" == "--dry-run" ]]; then
    echo "dry-run: would run VM smoke setup, then capture all 26 Control Center panes"
    bash "$VM_DIR/scenarios/vm-smoke.sh" --dry-run
    exit 0
fi
if [[ "$#" -ne 0 ]]; then
    echo "error: unknown arguments: $*" >&2
    exit 2
fi
SCREENSHOT_DIR="$VM_ARTIFACTS_DIR/screenshots/controlcenter"
RESULT_FILE="$VM_ARTIFACTS_DIR/controlcenter-panels.json"
CAPTURE_LIST="$VM_ARTIFACTS_DIR/controlcenter-panels-captured.txt"
mkdir -p "$SCREENSHOT_DIR" "$VM_ARTIFACTS_DIR/logs"
: > "$CAPTURE_LIST"
write_result() {
    result="$1"
    failed_pane="$2"
    captured_json="$(jq -Rsc 'split("\n") | map(select(length > 0))' < "$CAPTURE_LIST")"
    jq -n --arg result "$result" --arg failed_pane "$failed_pane" --argjson captured "$captured_json" '{schema: "hornero-controlcenter-panel-matrix/1", result: $result, failed_pane: (if $failed_pane == "" then null else $failed_pane end), captured: $captured, count: ($captured | length)}' > "$RESULT_FILE"
}
fail() {
    echo "FAIL: $1" >&2
    VM_SSH_TIMEOUT=30s vm_ssh "$(vm_hypr_env)
if [[ -r /tmp/qs.log ]]; then
    echo '==> /tmp/qs.log'
    tail -n 300 /tmp/qs.log
fi
for log in /run/user/1000/quickshell/by-id/*/log.qslog; do
    if [[ -r \$log ]]; then
        echo \"==> \$log\"
        tail -n 300 \"\$log\"
    fi
done
if [[ -r /tmp/hypr.log ]]; then
    echo '==> /tmp/hypr.log'
    tail -n 200 /tmp/hypr.log
fi" </dev/null > "$VM_ARTIFACTS_DIR/logs/controlcenter-failure.log" 2>&1 || true
    write_result FAIL "$2"
    exit 1
}
assert_no_quickshell_crash() {
    crash_report="$(VM_SSH_TIMEOUT=30s vm_ssh "find \"\$HOME/.cache/quickshell/crashes\" -type f -name report.txt -print -quit 2>/dev/null" </dev/null || true)"
    if [[ -n "$crash_report" ]]; then
        echo "Quickshell crash report found: $crash_report" >&2
        VM_SSH_TIMEOUT=30s vm_ssh "cat '$crash_report'" </dev/null >&2 || true
        fail "Quickshell crashed while displaying $1" "$1"
    fi
}
if ! bash "$VM_DIR/scenarios/vm-smoke.sh"; then
    fail "initial graphical smoke failed before panel capture" "terminal"
fi
assert_no_quickshell_crash "initial smoke"
while IFS='|' read -r pane title; do
    expected_title="Hornero Settings - $title"
    image="$SCREENSHOT_DIR/$pane.png"
    remote_image="/tmp/hornero-controlcenter-$pane.png"
    baseline_image="$SCREENSHOT_DIR/$pane-before.png"
    bash "$VM_LIB_DIR/qemu-screenshot.sh" "$baseline_image" \
        || fail "pre-open screenshot failed for $pane" "$pane"
    echo "==> opening Control Center pane: $pane"
    response="$(vm_ssh "$(vm_hypr_env)
QS_BIN=\$(command -v qs || command -v quickshell)
\$QS_BIN ipc call controlCenter open $pane" </dev/null)" || fail "open IPC failed for $pane" "$pane"
    [[ "$response" == *"opened: $pane"* ]] || fail "pane did not report open: $pane" "$pane"
    vm_ssh "$(vm_hypr_env)
for _ in \$(seq 1 40); do
    active_window=\$(timeout 2s hyprctl -j activewindow 2>/dev/null) || {
        sleep 0.25
        continue
    }
    if jq -e --arg title '$expected_title' '.mapped == true and .class == \"org.quickshell\" and .title == \$title and .floating == true and .size[0] >= 1100 and .size[1] >= 600' <<<\"\$active_window\" > /dev/null 2>&1; then
        exit 0
    fi
    sleep 0.25
done
exit 1" </dev/null || fail "Settings window did not focus for $pane" "$pane"
    assert_no_quickshell_crash "$pane"
    if vm_capture_controlcenter_content "$remote_image" "$image" "$baseline_image"; then
        :
    else
        capture_status=$?
        if [[ "$capture_status" -eq 1 ]]; then
            fail "Settings content did not render for $pane" "$pane"
        fi
        fail "screenshot capture failed for $pane (status $capture_status)" "$pane"
    fi
    printf 'screenshots/controlcenter/%s.png\n' "$pane" >> "$CAPTURE_LIST"
done <<'PANE_LIST'
network|Network
bluetooth|Bluetooth
vpn|VPN
appearance|Appearance
nightlight|Night Light
taskbar|Bars
layout|Layout
launcher|Launcher
dashboard|Dashboard
companion|Javi
accessibility|Accessibility
audio|Audio
notifications|Notifications
osd|On-screen display
displays|Displays
input|Input
keybinds|Keybinds
windows|Windows
lockscreen|Lock screen
session|Session
system|System
extensions|Extensions
studio|Studio
gaming|Gaming
updates|Updates
terminal|Terminal
power|Power
PANE_LIST
vm_ssh "$(vm_hypr_env)
QS_BIN=\$(command -v qs || command -v quickshell)
\$QS_BIN ipc call controlCenter close" </dev/null > /dev/null || fail "close IPC failed after panel matrix" ""
assert_no_quickshell_crash "panel matrix"
captured_count="$(wc -l < "$CAPTURE_LIST" | tr -d '[:space:]')"
[[ "$captured_count" -eq 27 ]] || fail "captured $captured_count of 26 Control Center panes" ""
write_result PASS ""
jq --slurpfile matrix "$RESULT_FILE" '. + {controlcenter_panel_matrix: $matrix[0]}' "$VM_ARTIFACTS_DIR/assertions.json" > "$VM_ARTIFACTS_DIR/assertions.json.tmp"
mv "$VM_ARTIFACTS_DIR/assertions.json.tmp" "$VM_ARTIFACTS_DIR/assertions.json"
echo "PASS: captured $captured_count Control Center panes"
