#!/usr/bin/env bash
# Runtime AT-SPI probe for the real Appearance pane option delegates.
#
# This opens one temporary Quickshell panel in the current Wayland session,
# using a scratch HOME/XDG tree, read-only horneroctl fixture, and scratch
# wallpaper. It does not lock the session or apply state.
# Usage: tests/atspi/run-appearance-probe.sh
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
scratch="$(mktemp -d)"
qpid=""
cleanup() {
    [[ -n "$qpid" ]] && kill "$qpid" 2>/dev/null || true
    rm -rf "$scratch"
}
trap cleanup EXIT

if [[ -z "${WAYLAND_DISPLAY:-}" || -z "${XDG_RUNTIME_DIR:-}" ]]; then
    echo "FAIL: a Wayland session is required" >&2
    exit 1
fi
command -v qs >/dev/null || { echo "FAIL: qs is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "FAIL: python3 is required" >&2; exit 1; }

mkdir -p "$scratch/bin" "$scratch/test-home" "$scratch/user-config" "$scratch/user-data" \
    "$scratch/user-state" "$scratch/user-cache" "$scratch/wallpapers" "$scratch/test-home/Pictures"
for d in assets components config services utils modules plugin; do
    [[ -e "$repo/$d" ]] && ln -sfn "$repo/$d" "$scratch/$d"
done
cp "$repo/tests/atspi/appearance-harness.qml" "$scratch/shell.qml"

# A tiny valid PPM keeps image delegates on their normal production path.
cat >"$scratch/wallpapers/Probe Wallpaper.ppm" <<'PPM'
P3
1 1
255
196 91 131
PPM

cat >"$scratch/fixture.json" <<EOF
{
  "themes": [{
    "id": "hornero-atspi-probe",
    "name": "Hornero AT-SPI Theme",
    "description": "Isolated accessibility fixture",
    "wallpaperDir": "hornero-atspi-probe",
    "wallpapers": ["Probe Wallpaper.ppm"],
    "defaultWallpaper": "Probe Wallpaper.ppm",
    "wallpaperPaths": {"Probe Wallpaper.ppm": "$scratch/wallpapers/Probe Wallpaper.ppm"},
    "darkMode": true,
    "schemeType": "tonal-spot",
    "collection": "atspi-fixture",
    "collectionOrder": 1,
    "tags": ["fixture"]
  }],
  "gtk_themes": "Hornero AT-SPI GTK Theme\nOrchis-Light-Compact\n",
  "icon_themes": "Hornero AT-SPI Icon Theme\nNumix-Circle\n",
  "schemes": {
    "Hornero AT-SPI Palette": {
      "tonal-spot": {
        "primary": "6750a4", "secondary": "625b71", "tertiary": "7d5260",
        "surface": "fff8ff", "error": "b3261e", "onBackground": "1c1b1f"
      }
    }
  },
  "current_scheme": "Hornero AT-SPI Palette\ntonal-spot\ntonalspot\n",
  "wallpaper": "$scratch/wallpapers/Probe Wallpaper.ppm"
}
EOF
cat >"$scratch/bin/horneroctl" <<EOF
#!/usr/bin/env bash
exec python3 "$repo/tests/atspi/horneroctl-fixture.py" "\$@"
EOF
chmod +x "$scratch/bin/horneroctl"

QT_ACCESSIBILITY=1 QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 \
HOME="$scratch/test-home" \
XDG_CONFIG_HOME="$scratch/user-config" \
XDG_DATA_HOME="$scratch/user-data" \
XDG_STATE_HOME="$scratch/user-state" \
XDG_CACHE_HOME="$scratch/user-cache" \
HORNERO_WALLPAPERS_DIR="$scratch/wallpapers" \
HORNERO_ATSPI_FIXTURE="$scratch/fixture.json" \
PATH="$scratch/bin:$PATH" \
    qs -p "$scratch/shell.qml" >"$scratch/qs.log" 2>&1 &
qpid=$!

expected=(
    "push button: Hornero AT-SPI Palette tonal-spot"
    "push button: Hornero AT-SPI GTK Theme"
    "push button: Hornero AT-SPI Icon Theme"
    "push button: Probe Wallpaper"
)

for _ in $(seq 1 45); do
    out="$(python3 "$repo/tests/atspi/probe.py" --pid "$qpid" 2>/dev/null || true)"
    ready=true
    for item in "${expected[@]}"; do
        if ! grep -Fq "$item" <<<"$out"; then
            ready=false
            break
        fi
    done
    font_rows="$(awk '
        /^push button: Material font family$/ { in_fonts = 1; next }
        /^push button: (Monospace|Sans-serif|Clock) font family$/ { in_fonts = 0 }
        /^push button: Probe Wallpaper/ { in_fonts = 0 }
        in_fonts && /^push button: Adwaita Sans(, current)?$/ { print }
    ' <<<"$out")"
    if [[ "$font_rows" != *"Adwaita Sans"* ]]; then
        ready=false
    fi
    if [[ "$ready" == true ]]; then
        echo "$out"
        if grep -q '^MUTATION_ATTEMPT$' "$scratch/user-state/hornero/atspi-cli.log" 2>/dev/null; then
            echo "FAIL: fixture observed a mutating CLI request" >&2
            cat "$scratch/user-state/hornero/atspi-cli.log" >&2
            exit 1
        fi
        echo "PASS: Appearance option delegates are exposed by AT-SPI"
        exit 0
    fi
    sleep 1
done

echo "FAIL: expected Appearance accessibles did not appear" >&2
cat "$scratch/qs.log" >&2
echo "$out" >&2
exit 1
