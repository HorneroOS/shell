# OSD, toast, notification roles

Three surfaces, three voices. A new message must pick exactly one —
if it fits two, the admission test at the bottom decides.

## OSD — the hardware echo (`modules/osd/`)

Momentary on-screen display for hardware levels happening right now:
speaker volume, microphone volume, screen brightness. Appears on
hardware change, auto-hides, and stays interactive while visible
(wheel and drag adjust the level in place).

- Trigger rule: hardware-level events only. Nothing else may summon
  the OSD.
- Never carries text announcements, never keeps history, never takes
  actions beyond adjusting its own level.

## Toast — the shell's own voice (`Toaster`, `modules/utilities/toasts/`)

Short confirmations and shell-detected conditions, spoken by the
shell about itself: settings saved/reloaded, Welcome progress,
battery state, VPN/audio/lock changes, media now-playing. Severity
is `Toast.Info` / `Success` / `Warning` / `Error`, also over IPC
(`qs ipc call toaster …`).

- Caller rule: shell internals only — never external applications.
- Auto-dismiss, no history, no actions. If the user must act on it
  later, it is not a toast.
- Click rule: left/middle dismisses (no history); right-click is
  ignored (D6, mirroring notifications). Hover does not pause
  expiry yet (C++ singleShot; pausable timer is I6).
- Gray areas, named not migrated: battery-critical and VPN-drop
  toasts arguably deserve notification promotion (history + DND).
  That migration is a code slice of its own; this doc only records
  the candidacy.

## Notification — applications' voice (`services/Notifs.qml`, `modules/notifications/`)

Messages from external applications, carried with their urgency and
expiry, DND-aware, kept in the notification center with history. On
the lock screen only the privacy-preserving dock shows (`NotifDock`:
presence without content).

- Source rule: external applications only — the shell never files
  its own messages here.
- Urgency and expiry come from the sender; the shell never invents
  either.

## Admission test

For a new message, ask in order:

1. Is it a hardware level right now? → OSD.
2. Is the shell confirming its own act or reporting a condition it
   detected? → toast.
3. Would it make sense coming from another application, revisited
   later, or silenced by DND? → notification.

If it fits none, it probably should not interrupt the user at all.
