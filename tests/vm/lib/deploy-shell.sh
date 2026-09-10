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
    echo "dry-run: would build the native QML plugin in the guest (prefix ${VM_GUEST_PREFIX}, skipped when unchanged)"
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
# Fresh cloud images have no ~/.config/hypr yet and scp cannot create it.
vm_ssh 'mkdir -p ~/.config/hypr'
vm_scp "${VM_DIR}/guest/hyprland.conf" "${VM_SSH_USER}@127.0.0.1:~/.config/hypr/hyprland.conf"

echo "==> verifying the deployed shell"
# shellcheck disable=SC2016
vm_ssh 'test -f ~/.config/quickshell/shell.qml && test -f ~/.config/hypr/hyprland.conf' || {
    echo "error: deployed tree is missing shell.qml or hyprland.conf" >&2
    exit 1
}

# --- native QML plugin (built from the deployed checkout, user prefix) ------
# Rebuilt only when the working tree changed (marker in the guest cache).
# shellcheck disable=SC2016 # remote $HOME must expand inside the guest
guest_home="$(vm_ssh 'printf %s "$HOME"')"
guest_prefix="${VM_GUEST_PREFIX//\$HOME/${guest_home}}"
tree_id="$(git -C "${SHELL_ROOT}" rev-parse HEAD):$(git -C "${SHELL_ROOT}" status --porcelain | sha256sum | awk '{ print $1 }')"
# shellcheck disable=SC2016
if vm_ssh "test -f ~/.cache/vm-harness-plugin-id && [ \"\$(cat ~/.cache/vm-harness-plugin-id)\" = '${tree_id}' ]" > /dev/null 2>&1; then
    echo "==> native plugin up to date, skipping rebuild"
else
    echo "==> building the native QML plugin in the guest (prefix ${guest_prefix})"
    # shellcheck disable=SC2016
    vm_ssh 'command -v cmake > /dev/null' || {
        echo "error: cmake missing in guest (provision.sh installs it)" >&2
        exit 1
    }
    # libcava is AUR-only: install it when the AUR knows it, else let the
    # build tell us whether it was actually required.
    # shellcheck disable=SC2016
    vm_ssh 'yay -Si libcava > /dev/null 2>&1 && yay -S --noconfirm --needed libcava || true'
    # Guest-side variables stay escaped so they expand inside the VM.
    if vm_ssh "set -e
cd ~/.config/quickshell
cmake -S . -B ~/.cache/hornero-shell-build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX='${guest_prefix}' -DINSTALL_QMLDIR='${guest_prefix}/lib/qt6/qml' -DINSTALL_LIBDIR='${guest_prefix}/lib/hornero' -DINSTALL_QSCONFDIR='${guest_prefix}/etc/xdg/quickshell/hornero'
cmake --build ~/.cache/hornero-shell-build -j\$(nproc)
cmake --install ~/.cache/hornero-shell-build"; then
        vm_ssh "printf %s '${tree_id}' > ~/.cache/vm-harness-plugin-id"
        echo "==> native plugin installed"
    else
        echo "warning: native plugin build failed; the shell starts without Hornero.* QML modules" >&2
    fi
fi
echo "==> shell deployed"
