#!/usr/bin/env bash
# Provision an Arch Linux container (CI job `shell-load`) with the exact
# Quickshell + Qt stack the shell runs on, then build and install libcava.
#
# Deterministic: every package comes from one Arch Linux Archive snapshot
# (ARCH_SNAPSHOT, YYYY/MM/DD), so a run months later installs the same
# versions. 2026/11/15 = quickshell 0.3.2-1, qt6-base 6.12.0-5,
# qt6-declarative 6.12.0-4, sway 1.12 (matches the reference host).
# Bump the date deliberately, in its own PR.
#
# Run as root inside the container. Idempotent: pacman --needed and an
# existing libcava.pc short-circuit repeat runs.
set -euo pipefail

if [ ! -f /etc/arch-release ]; then
    echo "ci_arch_shell_deps: Arch Linux only ($(uname -a))" >&2
    exit 1
fi

ARCH_SNAPSHOT="${ARCH_SNAPSHOT:-2026/11/15}"
CAVA_TAG="${CAVA_TAG:-1.0.0}"

echo "Server = https://archive.archlinux.org/repos/${ARCH_SNAPSHOT}/\$repo/os/\$arch" \
    > /etc/pacman.d/mirrorlist
# Keep the package cache (actions/cache restores it) and stop pacman from
# deleting it on success.
sed -i 's/^#\?CleanMethod.*/CleanMethod = KeepInstalled/' /etc/pacman.conf

# -Syyuu: refresh against the snapshot and move the image's packages to it
# (allows downgrades when the base image is newer than the snapshot).
pacman -Syyuu --noconfirm --needed \
    base-devel cmake ninja pkgconf git \
    qt6-base qt6-declarative qt6-svg qt6-wayland qt6-tools \
    quickshell sway dbus \
    libqalculate pipewire aubio fftw \
    ttf-ibm-plex \
    python python-pytest python-jsonschema python-fonttools python-pillow \
    nodejs

pacman -Q quickshell qt6-base qt6-declarative qt6-wayland sway

# sway ships with file capabilities (cap_sys_nice); container runtimes refuse
# to exec such binaries from an unprivileged user (EPERM). Drop them here.
setcap -r /usr/bin/sway 2>/dev/null || true

if pkg-config --exists libcava; then
    echo "libcava $(pkg-config --modversion libcava) already installed"
    exit 0
fi

# libcava is AUR-only on Arch; build the shared core from the same pinned
# fork and tag as the ubuntu `build` job.
src="$(mktemp -d)"
trap 'rm -rf "$src"' EXIT
git clone --quiet --depth 1 --branch "$CAVA_TAG" https://github.com/LukashonakV/cava "$src"
cc -shared -fPIC -O2 -I"$src" -I"$src/include" \
    -o "$src/libcava.so" "$src/cavacore.c" -lm -lfftw3
install -Dm755 "$src/libcava.so" /usr/local/lib/libcava.so
install -Dm644 "$src/include/cava/cavacore.h" "$src/include/cava/common.h" \
    "$src/include/cava/config.h" -t /usr/local/include/cava/
install -Dm644 "$src/include/cava/input/common.h" -t /usr/local/include/cava/input/
install -Dm644 "$src/include/cava/output/common.h" -t /usr/local/include/cava/output/
# Arch's pkgconf does not search /usr/local; the container is throwaway.
cat > /usr/lib/pkgconfig/libcava.pc <<EOF
prefix=/usr/local
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: libcava
Description: Shared library build of cava core (LukashonakV/cava)
Version: ${CAVA_TAG}
Libs: -L\${libdir} -lcava -lfftw3 -lm
Cflags: -I\${includedir}
EOF
echo /usr/local/lib > /etc/ld.so.conf.d/usr-local.conf
ldconfig
pkg-config --modversion libcava
