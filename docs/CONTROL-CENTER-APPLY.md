# Control Center: one apply policy

Status: implemented.
Applies to every pane under `modules/controlcenter/`.

## The policy

1. **Everything applies the moment you choose it.** There is no Apply, Save or Confirm button for a setting, in
   any pane. Toggles, sliders, pickers, tiles and presets act on click, drag-release or Enter.
2. **Free-text fields commit on Enter or when they lose focus**, never per keystroke (a half-typed keyboard
   layout list is not a layout). Number steppers that feed one command (the night-light times) commit after a
   short pause (700 ms), so typing `22:30` is one change.
3. **Where a preview is meaningful, hover or keyboard focus is a transient preview.** Pointing at a theme, a
   wallpaper or a Chromatic variant shows it; moving away puts the real thing back (Escape too). A preview never
   writes anything. Choosing the item is applying it.
4. **Risky, slow or hard-to-undo-by-hand changes apply immediately and offer Undo.** A non-blocking strip,
   "Applied · (what) · Undo", stays for `controlCenter.undoSeconds` (default 10, 3 to 60, Appearance > Look).
   Undo restores the previous value by the same atomic path that applied it. No confirm-then-apply step.
5. **One apply at a time, newest wins.** A change made while another is running replaces any queued older one
   and runs right after it. A failure leaves the previous value in place and the strip says what failed and why
   (`Undo.report`).
6. **Long derivations show progress inline** (Chromatic: "Building palette…" then "Applying…"; Appearance: the
   existing busy row) instead of a blocking dialog.

Two kinds of control are deliberately not "settings" and keep their shape. They are listed in the table so the
exceptions are visible, not hidden:

- **Commands without an inverse** (power off, system upgrade, snapshot restore, run a queued job, install or
  trust extension code, factory reset, delete all key overrides) keep a deliberate two-step guard. Undo cannot
  bring a rebooted machine or a ran job back, and installing code needs informed consent. These are verbs, not
  values.
- **Naming forms** (Save palette, Save preset, VPN provider dialog) create a new named object, and the **Theme
  editor** authors a document: its draft previews live and **Save as new / Save changes** writes the theme file.
  Nothing there is "applied" by saving (a saved theme is chosen later like any other). Deleting a palette is
  immediate with Undo.

## Why this policy (and the case for the opposite)

Hornero's principles are customisable, safe, retrofuturist-cozy and no destructive surprises.

- **Customisable and cozy** argue for immediacy: you drag a slider and the desktop answers. A staged form with an
  Apply button makes the Control Center feel like a tax form; the Signal look is an instrument panel, and
  instruments respond.
- **Safe and no surprises** are the strongest argument for the opposite (apply everywhere, behind a button).
  Taken seriously, that policy protects against a bad keyboard layout or a blank screen. But Apply does not make a
  change safer, it only delays it: a person who clicks Apply on a bad layout is exactly as locked out, and now
  has also paid a click on every harmless change. Undo protects against the same mistake after the fact, works
  for the cases where you cannot see the problem before applying (a palette on your real wallpaper, a layout on
  your real bars), and costs nothing when you are happy.
- **Consistency**: a mixed model (some panes live, some staged) is the worst case, because the person has to
  learn which pane is which. Most panes were already live (see the table); the staged ones were the exceptions
  (Chromatic, Input layouts, Keybinds, Assistant model and prompt, Night-light schedule), and most of those had
  no real reason to differ.
- **What Undo cannot do** is stated above. For those commands a guard is more honest than an Undo that lies.

The policy therefore chooses immediacy with a safety net for the risky tier, not a button.

## The shared mechanism

| Piece | File |
|-------|------|
| Service: `offer()`, `report()`, `undo()`, `dismiss()`, `restorer()` | `services/Undo.qml` |
| Strip: Undo and Dismiss buttons (Tab stops), `Ctrl+Z` outside text fields, countdown pauses while hovered or focused, reduced motion: no slide, no moving bar, a seconds readout instead | `modules/controlcenter/components/UndoStrip.qml` |
| Mounted once, bottom centre of the window | `modules/controlcenter/ControlCenter.qml` |
| Duration setting (3 to 60 s, default 10, validated by `config/ranges.json`) | `config/ControlCenterConfig.qml`, Appearance > Look |
| Voice (plain and cozy lines, plain line used for the accessible name) | `services/Microcopy.qml` (`undo.applied`, `undo.undone`) |

Restores never live in a pane (panes unload when you navigate away and die with the window). Callers describe
them as data and a singleton runs them: `offerCommand` (an argv Undo runs itself), `offerValues` and `offerPaths`
(remembered Config values), `offerCalls` (methods of singletons such as `ThemePipeline`, `Experience`).
A restore whose subsystem is busy answers `Undo.busy`: the offer stays and the undo retries for up to 10 s. Closing
the Control Center dismisses the offer and frees any hover hold (holds are counted, `Undo.releaseAll()`).

Rules the service enforces (and `tests/test_cc_apply_policy.py` runs against the real singleton): one offer at a
time; the same key coalesces and keeps the first restore point (dragging through five accents undoes all five);
a restore that returns `false`, a reason string or throws becomes a failure strip and changes nothing else.

How each risky change is made transactional:

| Change | Snapshot | Restore |
|--------|----------|---------|
| Layout preset (`services/PresetApply.qml`) | `shell.json` and the active-preset pointer copied (a missing file is recorded with an `.absent` marker, so a fresh account works) to `$XDG_STATE_HOME/hornero/shell/undo/<ts>/` (last 3 kept) before `horneroctl shell preset apply` | copy to a temp file next to the target, then `mv -f` (atomic rename) |
| Theme, wallpaper, GTK, icons, GTK scheme | live ids read before the pipeline job | the same `ThemePipeline` jobs with the old ids (Chromatic is re-derived) |
| Chromatic | theme id plus saved Chromatic preferences | `horneroctl appearance chromatic apply` with the old request, or the old theme and preferences if Chromatic was off |
| Look, atmosphere, bar sizes, plugin settings, customisation resets and imports | exact previous values (`Undo.restorer`) | write them back, one save |
| Keyboard layout, keybinding, assistant model and prompt, night-light schedule, power profile | previous value read from the CLI or pane | the inverse CLI call |
| Display arrangement | `hyprctl monitors all -j` | `hyprctl --batch keyword monitor …` per output |

Known limits, stated plainly: a layout Undo restores the whole `shell.json` as it was before the preset, so it
refuses, with a reason, when `shell.json` changed after the apply settled (its hash is recorded then) instead of
rolling those other changes back; and Mode-driven layouts (a mode that applies
its preferred layout when it starts) go through the Experience service, which has no strip, so the mode Undo
reverts the mode, not the layout.

## Audit: how each pane takes effect

Legend: **Live** = applies on change; **Click** = applies on click or pick; **Enter** = applies on Enter or blur;
**Pause** = applies after a short pause; **+Undo** = also offers the shared Undo; **Guard** = deliberate two-step
command; **Create** = naming form; **Hover** = transient hover or focus preview. "Before" says what the pane did
before this change when it differed.

| Pane (directory) | How a change takes effect now | Before | Evidence |
|------------------|-------------------------------|--------|----------|
| Appearance: Themes, Wallpaper, GTK theme, Icon theme, GTK colour scheme | Hover previews, click applies, +Undo | Click-to-apply (staged flags, no Undo) | `appearance/AppearancePane.qml:485` (`commitPending`), `:1067` (Undo offer); `appearance/sections/ThemesSection.qml:198`; `components/WallpaperGrid.qml:151`; `appearance/sections/IconThemeSection.qml:49`; `GtkThemeSection.qml:49`; `GtkColorSchemeSection.qml:90` |
| Appearance: Chromatic | Any choice applies once controls are quiet (350 ms), +Undo; variant tiles Hover; "Use Chromatic" switch; one apply in flight, newest wins | Edit, Preview on desktop, **Apply**, Cancel, "Ask me first" banner with Apply and Keep current | `services/ChromaticPreview.qml:356` (`_change`), `:709` (`applyQuiet`), `:699` (Undo offer); `appearance/sections/ChromaticSection.qml:120` (switch), `:189` (variant) |
| Appearance: Look, Atmosphere, Scales, Fonts, Border, Animations, Transparency, Background, Accent | Live; Look pack and "reset to factory" +Undo | Live, no Undo | `appearance/sections/LookSection.qml:98`; `AtmosphereSection.qml:37`; `ScalesSection.qml:40`; `FontsSection.qml:62`; `TransparencySection.qml:57`; `BackgroundSection.qml:26`; `AccentSection.qml:77` |
| Appearance: Edit palette | Draft previews live (Hover-style, memory only); **Create** on Save as new or Save changes; Delete is immediate +Undo | Delete had its own confirm and a 30 s local Undo | `appearance/sections/ThemeEditorSection.qml:522` (Save as new), `:150` (`deleteSaved`) |
| Layout | Click applies the preset, +Undo (snapshot of `shell.json`) | Applied, but a second click while busy was dropped | `layout/LayoutPane.qml:112`; `../layoutpicker/PresetGrid.qml:119` |
| Taskbar (bars) | Live; reset of a bar or of all sizes +Undo | Live | `taskbar/TaskbarPane.qml:86`; `taskbar/BarOrderEditor.qml:28`; `taskbar/BarGeometryEditor.qml:44` (reset bar), `:53` (sizes) |
| Experience | Switching a mode applies, +Undo (revert mode); picking the preferred layout applies it for the active mode; resetting a deck +Undo; **Guard** on Factory reset; **Create** Save preset | Separate "Apply layout now" button | `experience/ExperiencePane.qml:60`, `:341`, `:701`; `experience/DeckManager.qml:128`, `:246` |
| Customisation | Reset one or all applies at once, +Undo; importing a look pack +Undo | "Reset all" asked "Yes, reset all" | `customisation/CustomisationPane.qml:102` (`resetItems`), `:69` (`importPack`) |
| Input | Pointer and key tuning Live; layout list Enter +Undo; re-applying saved settings immediate | **Apply layouts** button; each restore needed a second click | `input/InputPane.qml:44` (`applyLayoutSet`), `:332`, `:349`, `:101`, `:466` |
| Keybinds | Rebind applies on Enter, +Undo; "Reset to defaults" is a **Guard** (an override list cannot be rebuilt) | **Apply** button | `keybinds/KeybindsPane.qml:103` (`applyRebind`), `:453` |
| Displays | Brightness Live; arrangement applies, +Undo (`hyprctl` snapshot); compositor layout and animation profile Click | Arrangement had no Undo | `displays/DisplaysPane.qml:124` (`applyMode`), `:90`, `:64` |
| Night light | Mode and temperature Live; schedule switch and times Pause, +Undo | **Set schedule** and **Clear schedule** buttons | `nightlight/NightLightPane.qml:63` (`send`), `:361`, `:319` |
| Gaming | Specialisation and app selection Live; power profile Click, +Undo | Power profile needed "Confirm" plus the profile name | `gaming/GamingPane.qml:129` (`setPerformance`), `:100` |
| Studio | Selection Live; **Guard** on Run job (executes a job) | Same | `studio/StudioPane.qml:178`, `:138` |
| Companion (assistant) | Model: pick a chip or Enter, +Undo; prompt saves on blur, +Undo; resets (nest, reactions, mode looks, position) +Undo | **Apply model**, **Save prompt** | `companion/CompanionPane.qml:1490` (`applyModel`), `:1503` (`applyPrompt`), `:1470` (queue); `../companion/CompanionStore.qml` |
| Extensions | Plugin settings Live, "Reset all" immediate +Undo; install, update, roll back, trust, enable keep **Guard** (consent to run code) | "Reset all" had a confirm | `extensions/PluginSettingsSection.qml:125`; `extensions/ExtensionsPane.qml:1418` |
| Power | **Guard** on power actions; idle and battery timings Live | Same | `power/PowerPane.qml:32`; `power/IdleBatteryPanel.qml:43` |
| Updates | **Guard** on upgrade, backup, snapshot restore | Same | `updates/UpdatesPane.qml:85` |
| System | Tiles run their command on click; diagnostics probes read-only | Same | `system/SystemPane.qml:107` |
| Audio | Device pick Click, volume Live | Same | `audio/AudioPane.qml:95` |
| Bluetooth | Power and discoverable Live; pairing is the device's dialog | Same | `bluetooth/Settings.qml:78` |
| Network (Wi-Fi, Ethernet, VPN) | Toggles Live; VPN provider dialog **Create** | Same | `network/NetworkSettings.qml:60`; `network/VpnList.qml:655`; `network/VpnDetails.qml:364` |
| VPN | Provider list Live | Same | `vpn/VpnPane.qml:142` |
| Notifications | Live | Same | `notifications/NotificationsPane.qml:117` |
| OSD | Live | Same | `osd/OsdPane.qml:73` |
| Session | Live | Same | `session/SessionPane.qml:83` |
| Lock screen | Live (next lock reads it) | Same | `lockscreen/LockScreenPane.qml:84` |
| Launcher | Live | Same | `launcher/Settings.qml:39` |
| Dashboard | Live | Same | `dashboard/GeneralSection.qml:90` |
| Accessibility | Live | Same | `accessibility/AccessibilityPane.qml:143` |
| Terminal | Pick applies (default terminal) | Same | `terminal/TerminalPane.qml:63` |
| Windows (compositor) | Gaps, border, rounding Live; rules **Create** (Add rule) | Same | `windows/WindowsPane.qml:79`, `:54` |
| Agents | Set default applies on click | Same | `agents/AgentCenterPane.qml:113` |
| Capture | Buttons run actions (screenshot, record) | Same | `capture/CapturePane.qml:188` |

Refresh, Scan and Reload buttons everywhere are **actions** (re-read the system), not settings, and stay.

## Adding a control

- A setting: write it when it changes. If it can lock you out, costs seconds, or is a bulk change, call
  `Undo.offer(key, title, restore, detail)` after it applied, or `Undo.report(key, title, reason)` if it failed.
- A text field: commit on `onEditingFinished`, validate, and keep one command in flight.
- Never add a button whose only job is to apply values you have already entered.
  `tests/test_cc_apply_policy.py` fails on the labels this change retired and on any new `Apply…` label.
