# HorneroOS Gaming Session (experimental)

The shell package ships an experimental, greeter-selectable Gamescope
session for the Gaming handheld specialization:

- `assets/hornero-gaming-session.desktop` installs to
  `/usr/share/wayland-sessions/` and is labelled Experimental.
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

## Qualification boundary

No device is hardware-qualified yet. Steam Deck is the reference
target; ROG Ally, Legion Go and other handhelds need their own
qualification. Until the `controller-handheld-session` item of the QA
Gaming acceptance gate passes on real hardware, this session is
experimental on every device: controller-only navigation, battery
reporting, suspend/resume and touchscreen behaviour are not certified.
The wrapper intentionally has no TDP or device-wide power controls.
