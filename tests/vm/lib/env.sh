#!/usr/bin/env bash
# Shared environment and helpers for the HorneroOS/shell graphical VM harness.
# Source this file from other scripts:
#   source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
#
# Every knob below is overridable through the environment. The harness boots
# a throwaway Arch Linux VM with QEMU/KVM, deploys this repo checkout as the
# Quickshell config under test, starts Hyprland plus the shell, and captures
# screenshots and recordings as artifacts. See docs/VM_TESTING.md.

# Harness root (tests/vm) and repo checkout under test.
# Exported: sourced scripts, dry-run probes, and helpers such as
# check_screenshot.py read these knobs from the environment.
VM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_ROOT="$(cd "${VM_DIR}/../.." && pwd)"

# Guest access.
VM_SSH_PORT="${VM_SSH_PORT:-2222}"
VM_SSH_USER="${VM_SSH_USER:-hornero}"
VM_SSH_DIR="${VM_SSH_DIR:-${VM_DIR}/ssh}"
VM_SSH_KEY="${VM_SSH_KEY:-${VM_SSH_DIR}/id_ed25519}"

# Host-side state directories (gitignored, see tests/vm/.gitignore).
VM_ARTIFACTS_DIR="${VM_ARTIFACTS_DIR:-${VM_DIR}/artifacts}"
VM_CACHE_DIR="${VM_CACHE_DIR:-${VM_DIR}/cache}"
VM_SHARED_DIR="${VM_SHARED_DIR:-${VM_DIR}/shared}"
VM_PID_FILE="${VM_CACHE_DIR}/qemu.pid"

# VM sizing. Keep modest so the harness can run next to a full desktop.
VM_MEM="${VM_MEM:-3072}"
VM_SMP="${VM_SMP:-2}"
VM_CLOUD_IMAGE_URL="${VM_CLOUD_IMAGE_URL:-https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2}"
VM_CLOUD_IMAGE="${VM_CLOUD_IMAGE:-${VM_CACHE_DIR}/arch-cloudimg.qcow2}"
VM_SEED_ISO="${VM_SEED_ISO:-${VM_CACHE_DIR}/seed.iso}"

# Recording knobs (mirror the dotfiles e2e defaults the harness is based on).
VM_FPS="${VM_FPS:-10}"
VM_RECORDING_REMOTE="${VM_RECORDING_REMOTE:-/tmp/vm-recording.mp4}"

# Set to 1 to print what a script would do without touching the VM.
VM_DRY_RUN="${VM_DRY_RUN:-0}"

export VM_DIR SHELL_ROOT
export VM_SSH_PORT VM_SSH_USER VM_SSH_DIR VM_SSH_KEY
export VM_ARTIFACTS_DIR VM_CACHE_DIR VM_SHARED_DIR VM_PID_FILE
export VM_MEM VM_SMP VM_CLOUD_IMAGE_URL VM_CLOUD_IMAGE VM_SEED_ISO
export VM_FPS VM_RECORDING_REMOTE VM_DRY_RUN

vm_is_dry_run() {
    [[ "${VM_DRY_RUN}" == "1" ]]
}

vm_usage_error() {
    echo "error: $1" >&2
    echo "usage: $2" >&2
    exit 2
}

# SSH into the harness VM.
vm_ssh() {
    ssh -4 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -o ConnectTimeout=5 \
        -i "${VM_SSH_KEY}" \
        -p "${VM_SSH_PORT}" \
        "${VM_SSH_USER}@127.0.0.1" "$@"
}

# SSH that detaches immediately after auth. Use it for launching long-lived
# graphical processes (compositor, shell, recorder) whose file descriptors
# would otherwise keep the session open. Output is discarded so backgrounded
# handles never keep caller pipes open.
vm_ssh_bg() {
    ssh -4 -f \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -o ConnectTimeout=5 \
        -i "${VM_SSH_KEY}" \
        -p "${VM_SSH_PORT}" \
        "${VM_SSH_USER}@127.0.0.1" "$@" > /dev/null 2>&1
}

# Copy files to or from the harness VM.
vm_scp() {
    scp -4 -O \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -i "${VM_SSH_KEY}" \
        -P "${VM_SSH_PORT}" \
        "$@"
}

# True when the QEMU process recorded in the pid file is still alive.
vm_running() {
    [[ -f "${VM_PID_FILE}" ]] && kill -0 "$(cat "${VM_PID_FILE}")" 2> /dev/null
}

# True when SSH is answering inside the VM.
vm_ssh_ready() {
    vm_ssh 'echo ok' > /dev/null 2>&1
}

# True when the Hyprland session is up inside the VM.
vm_session_ready() {
    vm_ssh 'pgrep -x Hyprland > /dev/null' > /dev/null 2>&1
}

# True when the shell (quickshell) process is up inside the VM.
vm_shell_ready() {
    vm_ssh 'pgrep -x qs > /dev/null 2>&1 || pgrep -x quickshell > /dev/null' > /dev/null 2>&1
}

# Environment exports needed before talking to the guest compositor session.
# The command substitution must expand on the guest, not locally.
# shellcheck disable=SC2016
vm_hypr_env() {
    echo 'export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t $XDG_RUNTIME_DIR/hypr/ | grep -v ".lock" | head -1)
export WAYLAND_DISPLAY=wayland-1
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_CONFIG_HOME=$HOME/.config
export QT_QPA_PLATFORM=wayland'
}
