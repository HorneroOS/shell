#!/usr/bin/env bash
# Remote/manual visual matrix for every Control Center destination.
set -euo pipefail
VM_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VM_LIB_DIR="$VM_ROOT/lib"
# shellcheck source=tests/vm/lib/env.sh
# shellcheck disable=SC1091
source "$VM_LIB_DIR/env.sh"
arg="${1-}"
if [[ "$arg" == "--help" ]]; then
    echo "usage: vm-controlcenter-panels.sh [--dry-run]"
    exit 0
fi
if [[ "$arg" == "--dry-run" ]]; then
    echo "dry-run: would run VM smoke setup, then capture all 16 Control Center panes"
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
mkdir -p "$SCREENSHOT_DIR"
: > "$CAPTURE_LIST"
write_result() {
    result="$1"
    failed_pane="$2"
    captured_json="$(jq -Rsc 'split("\n") | map(select(length > 0))' < "$CAPTURE_LIST")"
    jq -n --arg result "$result" --arg failed_pane "$failed_pane" --argjson captured "$captured_json" '{schema: "hornero-controlcenter-panel-matrix/1", result: $result, failed_pane: (if $failed_pane == "" then null else $failed_pane end), captured: $captured, count: ($captured | length)}' > "$RESULT_FILE"
}
fail() {
    echo "FAIL: $1" >&2
    write_result FAIL "$2"
    exit 1
}
bash "$VM_DIR/scenarios/vm-smoke.sh"
while IFS='|' read -r pane title; do
    expected_title="Hornero Settings - $title"
    image="$SCREENSHOT_DIR/$pane.png"
    remote_image="/tmp/hornero-controlcenter-$pane.png"
    echo "==> opening Control Center pane: $pane"
    response="$(vm_ssh "$(vm_hypr_env)
QS_BIN=\$(command -v qs || command -v quickshell)
\$QS_BIN ipc call controlCenter open $pane")" || fail "open IPC failed for $pane" "$pane"
    [[ "$response" == *"opened: $pane"* ]] || fail "pane did not report open: $pane" "$pane"
    vm_ssh "$(vm_hypr_env)
for _ in \$(seq 1 40); do
    if hyprctl -j activewindow | jq -e --arg title '$expected_title' '.class == \"org.quickshell\" and .title == \$title' > /dev/null; then
        exit 0
    fi
    sleep 0.25
done
exit 1" || fail "Settings window did not focus for $pane" "$pane"
    vm_ssh "$(vm_hypr_env)
timeout 15 grim '$remote_image'" > /dev/null 2>&1 || fail "screenshot capture failed for $pane" "$pane"
    vm_scp "$VM_SSH_USER@127.0.0.1:$remote_image" "$image" || fail "screenshot transfer failed for $pane" "$pane"
    python3 "$VM_LIB_DIR/check_screenshot.py" "$image" || fail "screenshot is blank or truncated for $pane" "$pane"
    printf 'screenshots/controlcenter/%s.png\n' "$pane" >> "$CAPTURE_LIST"
    vm_ssh "$(vm_hypr_env)
QS_BIN=\$(command -v qs || command -v quickshell)
\$QS_BIN ipc call controlCenter close" > /dev/null || fail "close IPC failed for $pane" "$pane"
    sleep 0.25
done <<'PANE_LIST'
network|Network
bluetooth|Bluetooth
vpn|VPN
appearance|Appearance
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
windows|Windows
lockscreen|Lock screen
session|Session
system|System
extensions|Extensions
updates|Updates
terminal|Terminal
power|Power
PANE_LIST
write_result PASS ""
jq --slurpfile matrix "$RESULT_FILE" '. + {controlcenter_panel_matrix: $matrix[0]}' "$VM_ARTIFACTS_DIR/assertions.json" > "$VM_ARTIFACTS_DIR/assertions.json.tmp"
mv "$VM_ARTIFACTS_DIR/assertions.json.tmp" "$VM_ARTIFACTS_DIR/assertions.json"
echo "PASS: captured $(wc -l < "$CAPTURE_LIST") Control Center panes"
