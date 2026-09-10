#!/usr/bin/env bash
# Start the harness VM with QEMU directly on the host.
# Idempotent: exits early when the recorded QEMU process is still alive.
# Usage: boot.sh [--dry-run]
#
# Requirements for a real boot: qemu-system-x86_64, curl, ssh-keygen, and one
# seed-ISO tool (cloud-localds, genisoimage, or mkisofs). /dev/kvm enables
# hardware acceleration; without it the script falls back to TCG and warns.

set -euo pipefail

VM_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/vm/lib/env.sh
# shellcheck disable=SC1091 # path resolves at runtime; use shellcheck -x to follow it
source "${VM_LIB_DIR}/env.sh"

if [[ "${1:-}" == "--help" ]]; then
    echo "usage: boot.sh [--dry-run]"
    exit 0
fi
if [[ "${1:-}" == "--dry-run" ]]; then
    export VM_DRY_RUN=1
fi

mkdir -p "${VM_SSH_DIR}" "${VM_ARTIFACTS_DIR}" "${VM_CACHE_DIR}" "${VM_SHARED_DIR}"

if vm_running; then
    echo "==> VM already running (pid $(cat "${VM_PID_FILE}"))"
    exit 0
fi
rm -f "${VM_PID_FILE}"

if vm_is_dry_run; then
    echo "dry-run: would generate SSH key at ${VM_SSH_KEY} (if missing)"
    echo "dry-run: would download ${VM_CLOUD_IMAGE_URL} to ${VM_CLOUD_IMAGE} (if missing)"
    echo "dry-run: would verify ${VM_CLOUD_IMAGE} against ${VM_CLOUD_IMAGE_SHA256_URL}"
    echo "dry-run: would grow ${VM_CLOUD_IMAGE} to ${VM_MIN_IMAGE_GB} GiB virtual size (if smaller)"
    echo "dry-run: would build seed ISO at ${VM_SEED_ISO} (if stale)"
    echo "dry-run: would start qemu (mem=${VM_MEM}MB smp=${VM_SMP} ssh=localhost:${VM_SSH_PORT})"
    exit 0
fi

command -v qemu-system-x86_64 > /dev/null || {
    echo "error: qemu-system-x86_64 is required (Arch: pacman -S qemu-desktop)" >&2
    exit 1
}

# --- ephemeral SSH key -------------------------------------------------------
if [[ ! -f "${VM_SSH_KEY}" ]]; then
    echo "==> generating ephemeral SSH key"
    ssh-keygen -t ed25519 -N '' -C vm-harness -f "${VM_SSH_KEY}" > /dev/null
fi
VM_SSH_PUBKEY="$(cat "${VM_SSH_KEY}.pub")"

# --- cloud image (cached after the first download, verified every run) -----
if [[ ! -f "${VM_CLOUD_IMAGE}" ]]; then
    echo "==> downloading Arch cloud image (cached after first run)"
    curl -fSL --retry 3 -o "${VM_CLOUD_IMAGE}" "${VM_CLOUD_IMAGE_URL}"
fi
if ! "${VM_LIB_DIR}/verify-image.sh" "${VM_CLOUD_IMAGE}" "${VM_CLOUD_IMAGE_SHA256_URL}"; then
    if [[ "${VM_ALLOW_UNVERIFIED_IMAGE}" == "1" ]]; then
        echo "warning: image verification failed, continuing because VM_ALLOW_UNVERIFIED_IMAGE=1" >&2
    else
        echo "error: image verification failed; deleting untrusted image" >&2
        rm -f "${VM_CLOUD_IMAGE}"
        echo "hint: set VM_ALLOW_UNVERIFIED_IMAGE=1 to bypass (not recommended)" >&2
        exit 1
    fi
fi

# --- image capacity (the stock cloud image is too small for the stack) ------
if command -v qemu-img > /dev/null; then
    img_bytes="$(qemu-img info --output=json "${VM_CLOUD_IMAGE}" 2> /dev/null | jq -r '.["virtual-size"] // 0')"
    img_bytes="${img_bytes//[^0-9]/}"
    img_bytes="${img_bytes:-0}"
    if [[ "${img_bytes}" -lt "$((VM_MIN_IMAGE_GB * 1024 * 1024 * 1024))" ]]; then
        echo "==> growing cloud image to ${VM_MIN_IMAGE_GB} GiB virtual size"
        qemu-img resize "${VM_CLOUD_IMAGE}" "${VM_MIN_IMAGE_GB}G"
    fi
else
    echo "warning: qemu-img not found, skipping capacity check (provision may run out of disk)" >&2
fi

# --- cloud-init seed (binds the current SSH key into the VM) -----------------
GUEST_DIR="${VM_DIR}/guest"
if [[ ! -f "${VM_SEED_ISO}" || "${VM_SEED_ISO}" -ot "${GUEST_DIR}/user-data.tmpl" ]]; then
    echo "==> building cloud-init seed ISO"
    sed "s|__VM_SSH_PUBKEY__|${VM_SSH_PUBKEY}|" \
        "${GUEST_DIR}/user-data.tmpl" > "${VM_CACHE_DIR}/user-data"
    cp "${GUEST_DIR}/meta-data" "${VM_CACHE_DIR}/meta-data"
    if command -v cloud-localds > /dev/null; then
        cloud-localds "${VM_SEED_ISO}" \
            "${VM_CACHE_DIR}/user-data" "${VM_CACHE_DIR}/meta-data"
    elif command -v genisoimage > /dev/null; then
        genisoimage -output "${VM_SEED_ISO}" -volid cidata -joliet -rock \
            "${VM_CACHE_DIR}/user-data" "${VM_CACHE_DIR}/meta-data" > /dev/null
    elif command -v mkisofs > /dev/null; then
        mkisofs -output "${VM_SEED_ISO}" -volid cidata -joliet -rock \
            "${VM_CACHE_DIR}/user-data" "${VM_CACHE_DIR}/meta-data" > /dev/null
    else
        echo "error: need cloud-localds, genisoimage, or mkisofs for the seed ISO" >&2
        exit 1
    fi
fi

# --- QEMU launch -------------------------------------------------------------
KVM_ARGS=(-enable-kvm -cpu host)
if [[ ! -w /dev/kvm ]]; then
    echo "warning: /dev/kvm not available, falling back to TCG (slow)" >&2
    KVM_ARGS=(-cpu max)
fi

echo "==> starting VM (mem=${VM_MEM}MB smp=${VM_SMP})"
# The monitor socket backs the qemu-screenshot.sh framebuffer fallback and
# the serial log keeps boot plus cloud-init output for troubleshooting.
qemu-system-x86_64 \
    "${KVM_ARGS[@]}" \
    -machine q35 \
    -smp "${VM_SMP}" \
    -m "${VM_MEM}" \
    -device virtio-vga \
    -drive "file=${VM_CLOUD_IMAGE},format=qcow2,if=virtio" \
    -drive "file=${VM_SEED_ISO},format=raw,if=virtio,media=cdrom,read-only=on" \
    -netdev "user,id=net0,hostfwd=tcp::${VM_SSH_PORT}-:22" \
    -device virtio-net-pci,netdev=net0 \
    -display none \
    -serial "file:${VM_ARTIFACTS_DIR}/console.log" \
    -monitor "unix:${VM_ARTIFACTS_DIR}/monitor.sock,server,nowait" \
    -usb -device qemu-xhci -device usb-tablet \
    -daemonize -pidfile "${VM_PID_FILE}"

echo "==> VM started (pid $(cat "${VM_PID_FILE}")). SSH localhost:${VM_SSH_PORT}, console: ${VM_ARTIFACTS_DIR}/console.log"
