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

# The archive is a single external host that sometimes stalls ("Operation
# too slow"). Download through curl with per-file retries and an explicit
# stall rule (below 10 KiB/s for 30 s counts as a failure and is retried),
# resuming partial files instead of restarting them.
sed -i '/^XferCommand/d' /etc/pacman.conf
sed -i '/^\[options\]/a XferCommand = /usr/bin/curl --fail --location --silent --show-error --retry 5 --retry-all-errors --retry-delay 5 --connect-timeout 20 --speed-limit 10240 --speed-time 30 --continue-at - --output %o %u' \
    /etc/pacman.conf

# Bounded retry around a whole pacman transaction (network only: the
# snapshot pins every version, so a retry installs exactly the same set).
pacman_retry() {
    local attempt
    for attempt in 1 2 3 4; do
        if pacman "$@"; then
            return 0
        fi
        echo "pacman $1 failed (attempt $attempt/4); retrying in $((attempt * 15))s" >&2
        rm -f /var/lib/pacman/db.lck
        sleep $((attempt * 15))
    done
    pacman "$@"
}

# Sync databases are pinned to the snapshot, so a cached copy (restored by
# actions/cache with the package cache) is exactly what -Syy would fetch.
# The stamp says which snapshot the cached databases belong to.
stamp=/var/lib/pacman/sync/.hornero-snapshot
if [ "$(cat "$stamp" 2>/dev/null || true)" = "$ARCH_SNAPSHOT" ] \
    && [ -s /var/lib/pacman/sync/core.db ] && [ -s /var/lib/pacman/sync/extra.db ]; then
    echo "sync databases for snapshot ${ARCH_SNAPSHOT} restored from cache"
else
    pacman_retry -Syy --noconfirm
    printf '%s\n' "$ARCH_SNAPSHOT" > "$stamp"
fi

# -Suu: move the image's packages to the snapshot (allows downgrades when
# the base image is newer than the snapshot) and install the stack.
pacman_retry -Suu --noconfirm --needed \
    base-devel cmake ninja pkgconf git \
    qt6-base qt6-declarative qt6-svg qt6-wayland qt6-tools \
    qt6-multimedia qt6-multimedia-ffmpeg \
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
