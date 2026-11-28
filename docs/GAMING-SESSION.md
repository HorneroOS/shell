# HorneroOS Gaming Session

The shell package ships a greeter-selectable Gamescope session for the Gaming
specialization:

- `assets/hornero-gaming-session.desktop` installs to
  `/usr/share/wayland-sessions/`.
- `scripts/hornero-gaming-session.sh` installs as
  `/usr/bin/hornero-gaming-session`. It fails closed when `gamescope`
  or `steam` is missing (Steam stays an explicit opt-in), then execs
  `gamescope -- steam -gamepadui`. `HORNERO_GAMING_WIDTH`,
  `HORNERO_GAMING_HEIGHT` and `HORNERO_GAMING_REFRESH` optionally pin
  the output mode; defaults follow the connected display.

Exiting Steam ends the session and returns to the greeter, where the
normal HorneroOS desktop session can be selected again. Hornero Shell
owns this session entry and wrapper (decision recorded in shell#336);
hornero-config owns reversible defaults and `horneroctl gaming doctor`
owns capability truth.

## Hardware qualification notes

Steam Deck is the reference handheld target; ROG Ally, Legion Go, and
other handhelds require device-specific hardware qualification for
controller-only navigation, battery reporting, suspend/resume, and
touchscreen behaviour. The wrapper intentionally has no TDP or
device-wide power controls.
