# Appearance pane UX: host captures

Real Hyprland session, 1920x1080, Control Center window only. Captured on 2026-11-18.
The full set and the notes are in the mission evidence folder (appearance-ux/NOTES.md).

- `before-01-idle.png`: `main`. Chromatic sits above Themes. The preview shows a stale
  wallpaper card, not what is applied.
- `before-03-after-pointer-leaves.png`: `main`. After pointing at Signal Day and leaving, the
  preview stays on Signal Day.
- `after-01-idle.png`: this PR, idle state:
  - the pinned "Now using" strip (cozy voice: "Wearing now")
  - the grouped sections, with Themes first
  - the preview banner
  - the specimen drawn from the applied palette
  - measured contrast
- `after-02-preview-day.png`: this PR, pointing at Signal Day. The cue banner reads "Nothing
  has changed yet". The strip still names the applied look and adds a "Trying on" note.
- `after-04-chromatic-style-preview.png`: this PR, pointing at the Chromatic Vibrant tile. The
  whole desktop shows Vibrant, and the banner and specimen name it.

The captures were driven by a validation-only IPC driver, which is not part of this PR. It
calls the same functions that pointer hover and leave call.
