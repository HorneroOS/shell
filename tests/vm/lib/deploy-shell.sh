#!/usr/bin/env bash
# Deploy the repo checkout under test into the VM as the live Quickshell
# config, plus the minimal harness Hyprland config for the test session.
# Usage: deploy-shell.sh [--dry-run]
#
# Only tracked plus untracked-not-ignored files travel (exactly the working
# tree under test); build output, the harness cache, and guest state stay out.

set -euo pipefail

VM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/vm/lib/env.sh
# shellcheck disable=SC1091 # path resolves at runtime; use shellcheck -x to follow it
source "${VM_LIB_DIR}/env.sh"

if [[ "${1:-}" == "--help" ]]; then
    echo "usage: deploy-shell.sh [--dry-run]"
    exit 0
fi
if [[ "${1:-}" == "--dry-run" ]]; then
    export VM_DRY_RUN=1
fi

if vm_is_dry_run; then
    echo "dry-run: would copy ${SHELL_ROOT} working tree to guest ~/.config/quickshell"
    echo "dry-run: would install tests/vm/guest/hyprland.conf to guest ~/.config/hypr/hyprland.conf"
    exit 0
fi

vm_ssh_ready || {
    echo "error: VM SSH is not up. Run lib/boot.sh + lib/wait-ssh.sh first." >&2
    exit 1
}

echo "==> copying shell working tree into the VM (~/.config/quickshell)"
cd "${SHELL_ROOT}"
git ls-files -co --exclude-standard | tar cf - -T - 2> /dev/null \
    | vm_ssh 'rm -rf ~/.config/quickshell && mkdir -p ~/.config/quickshell && tar xf - -C ~/.config/quickshell'

echo "==> installing harness Hyprland config (test session only)"
vm_scp "${VM_DIR}/guest/hyprland.conf" "${VM_SSH_USER}@127.0.0.1:~/.config/hypr/hyprland.conf"

echo "==> verifying the deployed shell"
# shellcheck disable=SC2016
vm_ssh 'test -f ~/.config/quickshell/shell.qml && test -f ~/.config/hypr/hyprland.conf' || {
    echo "error: deployed tree is missing shell.qml or hyprland.conf" >&2
    exit 1
}
echo "==> shell deployed"
