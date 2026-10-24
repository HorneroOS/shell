#!/usr/bin/env bash
# Install the exact libcava AUR source revision needed to build Hornero's
# native QML plugin on a stock Arch VM (the official `cava` package is CLI-only).
set -euo pipefail

readonly AUR_REPOSITORY="https://aur.archlinux.org/libcava.git"
readonly AUR_COMMIT="39403443c8208f5d9adaaed7c8347c439efe52cf"
readonly BUILD_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hornero-vm-libcava"

if pkg-config --exists libcava; then
    echo "libcava development library is already installed"
    exit 0
fi

mkdir -p "$BUILD_DIR"
git -C "$BUILD_DIR" init --quiet
if ! git -C "$BUILD_DIR" remote get-url origin >/dev/null 2>&1; then
    git -C "$BUILD_DIR" remote add origin "$AUR_REPOSITORY"
fi
git -C "$BUILD_DIR" fetch --quiet --depth=1 origin "$AUR_COMMIT"
git -C "$BUILD_DIR" checkout --quiet --detach FETCH_HEAD
actual_commit="$(git -C "$BUILD_DIR" rev-parse HEAD)"
if [[ "$actual_commit" != "$AUR_COMMIT" ]]; then
    echo "error: libcava AUR source revision mismatch: $actual_commit" >&2
    exit 1
fi

# makepkg must run as the unprivileged VM user; --syncdeps uses sudo only for
# pacman dependencies and package installation inside this disposable guest.
cd "$BUILD_DIR"
makepkg --syncdeps --install --noconfirm --cleanbuild --clean
pkg-config --modversion libcava >/dev/null
echo "libcava development library installed from pinned AUR revision $AUR_COMMIT"
