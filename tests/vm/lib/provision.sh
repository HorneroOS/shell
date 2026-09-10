#!/usr/bin/env bash
# Install the desktop stack inside the harness VM (idempotent: skipped when
# the guest marker file exists, so repeat runs only re-provision explicitly).
# Usage: provision.sh [--dry-run]
#
# Quickshell ships through the AUR, so provisioning bootstraps yay first and
# then installs quickshell plus the Qt6 modules the shell needs. This is the
# slowest harness stage on first boot; afterwards the marker makes it instant.

set -euo pipefail

VM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/vm/lib/env.sh
# shellcheck disable=SC1091 # path resolves at runtime; use shellcheck -x to follow it
source "${VM_LIB_DIR}/env.sh"

if [[ "${1:-}" == "--help" ]]; then
    echo "usage: provision.sh [--dry-run]"
    exit 0
fi
if [[ "${1:-}" == "--dry-run" ]]; then
    export VM_DRY_RUN=1
fi

if vm_is_dry_run; then
    echo "dry-run: would check guest free disk space (fail fast below ${VM_MIN_GUEST_FREE_GB} GB)"
    echo "dry-run: would install guest packages (pacman incl. cmake + AUR quickshell)"
    echo "dry-run: would enable seatd and grant seat/video/render groups"
    echo "dry-run: would write the provision marker when done"
    exit 0
fi

vm_ssh_ready || {
    echo "error: VM SSH is not up. Run lib/boot.sh + lib/wait-ssh.sh first." >&2
    exit 1
}

echo "==> checking guest free disk space (need ${VM_MIN_GUEST_FREE_GB} GB)"
# shellcheck disable=SC2016
guest_free_kb="$(vm_ssh 'df --output=avail -k / | tail -n 1' | tr -d '[:space:]')"
if [[ "${guest_free_kb}" -lt "$((VM_MIN_GUEST_FREE_GB * 1024 * 1024))" ]]; then
    echo "error: guest has only $((guest_free_kb / 1024)) MB free, need ${VM_MIN_GUEST_FREE_GB} GB." >&2
    echo "hint: enlarge the image with: qemu-img resize <image> +12G (see boot.sh capacity step)" >&2
    exit 1
fi

if vm_ssh 'test -f ~/.cache/vm-harness-provisioned' > /dev/null 2>&1; then
    echo "==> VM already provisioned"
    exit 0
fi

echo "==> installing guest desktop stack (this takes a while on first boot)"
# Remote script on purpose: every expansion below must happen on the guest.
# shellcheck disable=SC2016
vm_ssh 'sudo pacman -Sy --noconfirm --needed --overwrite "/usr/lib/*" \
    hyprland xdg-desktop-portal-hyprland \
    pipewire wireplumber pipewire-pulse \
    seatd polkit \
    grim slurp wf-recorder \
    kitty qt6-base qt6-declarative qt6-svg qt6-multimedia qt6-wayland \
    base-devel cmake git curl jq \
    pipewire-jack aubio \
    noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd'

echo "==> bootstrapping yay for AUR packages (quickshell)"
# shellcheck disable=SC2016
vm_ssh 'if ! command -v yay > /dev/null; then \
    rm -rf /tmp/yay-bin && git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin && \
    (cd /tmp/yay-bin && makepkg -si --noconfirm) && rm -rf /tmp/yay-bin; fi'

echo "==> installing quickshell from the AUR"
# shellcheck disable=SC2016
vm_ssh 'yay -S --noconfirm --needed quickshell-git'

echo "==> granting DRM and seat access"
# SSH sessions have no logind seat, so seatd handles DRM device access.
# shellcheck disable=SC2016
vm_ssh 'sudo systemctl enable --now seatd && \
    sudo gpasswd -a "$USER" seat > /dev/null && \
    sudo gpasswd -a "$USER" video > /dev/null && \
    sudo gpasswd -a "$USER" render > /dev/null'

vm_ssh 'mkdir -p ~/.cache && touch ~/.cache/vm-harness-provisioned'
echo "==> provisioned"
