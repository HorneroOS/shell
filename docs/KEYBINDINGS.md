# Keybinding overlay and rebinding

Press **Super + /** to open the keybinding overlay. It lists every bind the
compositor runs right now, grouped by purpose, and lets you run or rebind any of
them without editing a config file.

## What the overlay shows

- **Every active bind.** The list comes from `horneroctl hardware keyboard
  rebind list`, which reads `hyprctl binds -j` and adds the category and a
  readable action from the Hornero config. Plugin and runtime binds that are in
  no config file show up under **Other**. Submap binds (resize mode, gaps mode,
  the overview plugin) show up with their submap name.
- **Groups with Hornero Glyphs**: Essential applications, Window management,
  Focus movement, Window movement and resizing, Scrolling layout, Workspaces,
  Groups, Media keys, Screenshots, System control, Mouse, Personal (binds from
  your `keybindings-user.lua`) and Other.
- **Moved binds** show their keys highlighted and say which combo they came
  from.

Search filters as you type. Every word has to match the keys, the action or the
group name, in English or Spanish ("foco", "ventanas", "capturas" work).

## Keys

| Key | Action |
| --- | --- |
| Up / Down, Tab, Ctrl+N / Ctrl+P | Move the highlight |
| Page Up / Page Down | Move by eight rows |
| Enter (or double-click) | Run the highlighted bind |
| Ctrl+E | Rebind the highlighted bind in place |
| Ctrl+D | Disable the highlighted bind |
| Ctrl+Z | Undo the last keybinding change |
| Escape | Clear the search, then close |

## Rebinding in place

1. Highlight a bind and press **Ctrl+E** (or **Rebind**).
2. Press the new combo. While the overlay records it, Hyprland waits in an
   empty `hornero_capture` submap, so a combo that is already taken reaches the
   overlay instead of running. Escape cancels. The capture ends on its own
   after 15 seconds, so a session can never get stuck there.
3. If the combo is free, press **Enter** to save. If it is taken, the overlay
   names the bind that holds it and its group. Press **S** to swap the two, or
   **R** to try another combo.

The change applies immediately (`hyprctl reload`). **Undo** in the footer, or
Ctrl+Z, puts back exactly what was there before, swaps included. It keeps up to
20 steps.

The summon key is an ordinary bind. To open the overlay with Super + K like
Omarchy, rebind the "keyboard keys" entry to Super + K and swap when it asks.
Super + K is the factory focus-up key.

## Where rebinds are stored

On the factory Lua config, rebinds never edit `keybindings.lua` or your
`keybindings-user.lua`. They go to a generated file that the config owns:

```text
~/.config/hypr/hornero-keybinds.lua               remap table (data only)
~/.local/state/hornero/keybinds/undo/NNNNNN.lua   undo snapshots
```

`hyprland.lua.d/keybindings-overlay.lua` (HorneroOS/config) loads before any
bind. It moves each remapped combo wherever it is used, so an unbind/bind pair
in your `keybindings-user.lua` follows the rebind. It loads the generated file
with an empty environment, so the file can only hold data. A missing or broken
file leaves every bind exactly as written.

Configs that still use hyprlang keep their older overrides in
`keybindings-user.conf`. On those configs, Undo moves a bind back and
Disable is not offered.

## Command line

```sh
horneroctl hardware keyboard rebind list --json      # every bind, JSON in data.entries
horneroctl hardware keyboard rebind set --old "SUPER + Return" --new "SUPER + X" --yes
horneroctl hardware keyboard rebind set --old "SUPER + K" --new "SUPER + J" --swap --yes
horneroctl hardware keyboard rebind set --old "SUPER + K" --new none --yes   # disable
horneroctl hardware keyboard rebind undo --yes
horneroctl hardware keyboard rebind reset --yes
```

Shell IPC: `qs ipc call keybinds toggle|open <query>|close|isOpen`. The overlay
also registers the `hornero:keybinds` global shortcut.

## Settings

Control Center > Keybinds > Keybinding overlay holds these settings. They are
stored in `shell.json` under `keybinds.overlay`:

| Setting | Default | Effect |
| --- | --- | --- |
| `runOnEnter` | `true` | Enter runs the highlighted bind |
| `closeAfterRun` | `true` | The overlay closes before running, so the bind acts on your window |
| `showSubmaps` | `true` | List submap binds |
| `showMouse` | `true` | List mouse binds |
| `compact` | `false` | Denser rows |

The same pane shows the summon key with a **Change** button. It also lists
every bind with the same rebind editor: record or type a combo, conflicts
shown before applying, Swap, Disable, Undo, and Reset to defaults.

## SUPER-hold key badges

Holding bare SUPER for a moment shows a key badge on each bar workspace cell:
the key that focuses that workspace (`0` on workspace 10, or whatever key a
rebind moved it to — badges read the same live bind list as the overlay).
Releasing SUPER hides them, and pressing any SUPER shortcut hides them too —
shortcuts are never delayed or swallowed, because detection uses
non-consuming `global` binds registered by HorneroOS/config
(`keybindings-overlay.lua`): an arm bind on the SUPER key itself
(`hornero:superHoldArm`), a release bind (`hornero:superHoldRelease`), and one
interrupt twin next to every SUPER combo (`hornero:superHoldInterrupt`). Those
three are shell plumbing and never appear in the overlay list. Badges never
show over a fullscreen window. Hyprland only for now; on Niri the shortcuts
stay inert.

Stored in `shell.json` under `keybinds.superHold`, edited in Control Center >
Keybinds > SUPER-hold key badges (with reset to defaults):

| Setting | Default | Effect |
| --- | --- | --- |
| `enabled` | `true` | Turn the badges off entirely |
| `holdMs` | `600` | How long SUPER must be held alone (200–3000 ms) |
