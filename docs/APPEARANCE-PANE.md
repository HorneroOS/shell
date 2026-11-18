# Appearance pane: layout and state model

Control Center > Appearance follows the one apply policy in
[CONTROL-CENTER-APPLY.md](CONTROL-CENTER-APPLY.md): every choice applies when you
click it, there is no Apply button, and risky or slow changes show "Applied · Undo".
This page describes how the pane makes that policy easy to read.

## The three states

The pane always shows which of three states it is in. The words come from
`services/Microcopy.qml`, in the plain and the cozy voice.

| State | Meaning | Where it shows |
|---|---|---|
| Now using | The preview shows what is applied | Preview banner (neutral, check glyph) |
| Previewing | You are pointing at or focusing an option. Nothing has changed yet | Preview banner (cue colour, eye glyph), a note in the "Now using" strip, a "Previewing · Click to use" chip on the item |
| Applying | A click is being applied | Preview banner, the "Now using" strip, an "Applying" chip on the item |

Rules:

- **"Now using" never shows a preview.** The strip pinned above the sections names the applied
  theme, or Chromatic with its style, mode and source, over the applied colours. While the
  live desktop shows a Chromatic style you are pointing at, the strip reads Signal's pre-preview
  snapshot.
- **A preview ends when the pointer or keyboard focus leaves.** The preview then goes back to
  "Now using". It never stays on the last item you pointed at, and it never shows an empty card.
  Escape also ends a Chromatic style preview.
- **Theme, wallpaper and colour-scheme previews stay in the preview area.** Chromatic style
  tiles preview on the whole desktop, as #667 defined. The banner says so.
- **Undo sits next to what it would put back.** When the last appearance or Chromatic change can
  still be undone, the "Now using" strip shows an Undo button. The shared strip at the bottom of
  the Control Center makes the same offer. Both call `services/Undo.qml`.
- **Selection has one look everywhere.** The applied item is filled with the signal well, has a
  2 px signal border, a check glyph (a heart with cozy chips) and the words "In use". Pointing at
  an item gives it a cue border. State is always shown with a glyph and words, never colour alone.

Hover previews are a user setting: `controlCenter.appearanceHoverPreview`, Appearance > Look,
default on. Turned off, nothing changes until you click.

## Section order

| Group | Sections | Why here |
|---|---|---|
| Colour | Themes, Chromatic, Accent, Edit palette | Picking a look is the first thing people do. Themes come first because a curated look is the quickest good result. Chromatic, the dynamic alternative, comes right after it. Accent and Edit palette adjust whichever palette is in use, so they follow the two ways of choosing one |
| Wallpaper & desktop | Background | The wallpaper grid stays in the right column below the preview. This section holds the desktop clock and the visualiser |
| Look & feel | Look, Atmosphere, Transparency, Border | Shell shape and mood |
| Type & motion | Fonts, Scales, Animations | Fine tuning |
| Apps: GTK, Qt and icons | GTK theme, GTK colour scheme, Icon theme | These affect other apps, not the shell, so they come after the shell's own look |
| Health | Health & sync | Diagnostics, so it comes last |

One change from the brief: **Accent and Edit palette sit inside Colour**, before Wallpaper.
They change the palette in use, so placing them after Wallpaper or Look would split up the
colour controls.

Saved palettes are listed once, under Themes > Your palettes. There, pointing at one previews
it, and a click applies it with Undo. Chromatic keeps "Save this palette", Import and Export.

## The preview

The right column is large, and its size does not change between states. It holds:

1. The state banner.
2. The same sample desktop Chromatic uses (bar, launcher, popout, notification, terminal
   colours, telemetry trace), drawn only from the previewed palette and wallpaper.
3. Measured WCAG contrast for that palette: text on ground and muted text on panel at 4.5:1,
   accent on ground at 3:1, text on the accent well at 4.5:1. Each check shows the colour pair,
   the ratio and a pass or fail glyph.
4. The name, mode and wallpaper. The GTK, icon and wallpaper-pack recipe is under Details.

## Accessibility and motion

- The "Now using" strip, the banner and every contrast check have accessible names.
- Theme cards are radio buttons with a checked state. Keyboard focus previews exactly like the
  pointer does.
- Group headings are headings.
- Under reduced motion nothing animates. The only transition is the preview border colour, and
  it is turned off when motion is reduced.

## Tests

- `tests/test_appearance_ux.py`: static contract plus offscreen renders of the real pane
  through `tests/qml/appearance/harness.qml`. The renders check section order, the strip, the
  banner states, a theme preview followed by a return to "Now using", the Chromatic style
  preview, and that no Apply button exists.
- `python3 tests/appearance_ux_harness.py <out.png> <scene> [shell-tree]` writes evidence PNGs.
  The scenes are `idle`, `preview-theme`, `preview-end`, `preview-variant` and `collapsed`.
