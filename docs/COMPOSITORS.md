# Compositor integration

Hornero Shell owns one desktop experience. A compositor backend supplies the
session capabilities that the Shell can use; it does not define Hornero's
visual identity. Backends must report limitations explicitly. A feature that
does not map cleanly stays unavailable until the Shell has a deliberate
interaction for it.

## Current state

The shipped Shell is integrated with Hyprland through Quickshell's native
`Quickshell.Hyprland` module and `services/Hypr.qml`. `services/Compositor.qml`
is the capability-aware boundary for shared UI. Niri currently supplies live
workspace/window events, focus/close/floating/fullscreen actions, workspace
navigation, monitor power, keyboard layout state/switching, and focused-output
routing. The bar workspace view and Dashboard window list use these native
models. Layer-shell surfaces can take explicit keyboard focus without using
Hyprland's focus-grab object.

This is an experimental integration, not a supported Niri session claim.
Several functions still rely on Hyprland-specific APIs, including output
metadata and brightness targeting, area picking, native window thumbnails,
game mode, lock-state indicators, session startup, and some layout actions.
Niri does not currently report fullscreen state through its event stream, so
the Shell offers the fullscreen action but does not claim fullscreen-state
parity. Session configuration, portals, lock behavior, and graphical QA must
be covered together before Niri can be called supported.

## Niri session adapter

`services/Niri.qml` uses `niri msg --json event-stream`. Niri sends a complete
initial snapshot and then state changes over one long-lived IPC stream, so the
adapter does not poll. It retains native workspace and window identities and
uses Niri actions for focus, close, fullscreen, and workspace movement.
Commands are passed as argument arrays; user-provided text is never evaluated
by a shell.

The adapter exposes workspace/window state and a deliberately limited
capability map. It does not claim live output metadata, workspace creation or
renaming, Hyprland special workspaces, Hyprland layout controls, native window
thumbnails, fullscreen state, or Quickshell global shortcuts. Niri's
workspaces are dynamic and its columns are not Hyprland's `dwindle`/`master`
layouts; the Layout Picker must offer Niri-appropriate behavior rather than
translating these concepts silently.

## Current graphical evidence

A disposable QEMU guest running Niri v26.04 at 1280×800 has been used with
real keyboard and pointer input. The exercised journey includes Shell startup,
Launcher, Dashboard, Control Center, Appearance, applying Hornero Light,
opening Layout Picker and applying Hornero Left, changing workspaces, and
Niri's screenshot selector. This is single-output exploratory acceptance.
It does not yet certify multiple outputs, OBS/screencast portals, lock/session
recovery, or all Shell surfaces. The host Hyprland session was not changed.

## Backend contract

Before a Shell surface uses a compositor feature, it should query or receive
that capability from the active adapter. The integration boundary is expected
to cover:

| Domain | State/actions | Notes |
| --- | --- | --- |
| Identity | backend ID and capabilities | Never infer support from a package being installed. |
| Workspaces | list, active/focused state, focus, move | Preserve native IDs and activation semantics. |
| Windows | active/list state, focus, close, fullscreen | Thumbnail capture is optional. |
| Outputs | enumerate, focused output, screen mapping | Hotplug and scaling behavior must be stated. |
| Session | launch, lock, idle, screenshot, screencast | Use compositor-specific session integration where needed. |

Labwc is a future backend candidate. Its `wlr-layer-shell` and
`wlr-foreign-toplevel-management` integration is distinct from Niri's IPC; it
must be implemented and tested against Labwc rather than treated as another
Niri or Hyprland mode.

## Validation gate

A backend is not supported because its config parses or its adapter can read
one IPC response. It must boot as a real session and demonstrate Shell startup,
workspace/window interaction, outputs, portals, screenshots, lock/session
behavior, notifications, settings, and recovery in graphical QA. The product
website and edition metadata must use the same maturity label as that evidence.

## Upstream references

- [Niri IPC and event stream](https://niri-wm.github.io/niri/IPC.html)
- [Niri workspaces](https://niri-wm.github.io/niri/Workspaces.html)
- [Niri screencasting](https://niri-wm.github.io/niri/Screencasting.html)
- [Labwc integration](https://labwc.github.io/integration.html)
