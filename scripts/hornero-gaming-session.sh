#!/bin/sh
# HorneroOS Gaming Session (experimental): a Gamescope session running
# Steam's controller-friendly interface. Exiting Steam ends the session
# and returns to the greeter, where the normal HorneroOS desktop session
# can be selected again. This never claims hardware qualification: on
# unqualified devices it is an experimental session, and HorneroOS
# doctor (horneroctl gaming doctor) remains the capability source of
# truth. No power/TDP manipulation, no root, no background services.
set -eu

if ! command -v gamescope >/dev/null 2>&1; then
    echo "hornero-gaming-session: gamescope is not installed; select the Gaming specialization in HorneroOS first." >&2
    exit 1
fi
if ! command -v steam >/dev/null 2>&1; then
    echo "hornero-gaming-session: Steam is not installed; Steam is an explicit opt-in (horneroctl gaming selection)." >&2
    exit 1
fi

# Optional display overrides; defaults follow the connected display.
width="${HORNERO_GAMING_WIDTH:-}"
height="${HORNERO_GAMING_HEIGHT:-}"
refresh="${HORNERO_GAMING_REFRESH:-}"

set -- gamescope
[ -n "$width" ] && set -- "$@" -W "$width"
[ -n "$height" ] && set -- "$@" -H "$height"
[ -n "$refresh" ] && set -- "$@" -r "$refresh"
set -- "$@" -- steam -gamepadui

exec "$@"
