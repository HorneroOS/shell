# HorneroOS Experience Baseline — Phase 1 Research Deliverable

> Status: research in progress. This document records **evidence-backed**
> observations only. Nothing here authorizes redesign yet.
> Baseline commit: `HorneroOS/shell@79d7fff`, host verified byte-identical
> (`~/.config/quickshell` diff clean except `__pycache__`).
> Screenshots: `/tmp/hornero-baseline/` (13 captures, 1920x1080, dark unless noted).

## 1. Current experience map (verified live via `qs ipc`)

IPC targets on shell main: `idleInhibitor, welcome (open/close/status),
companion, notifs, appearance, controlCenter (open only), drawers
(bar/osd/session/launcher/dashboard/utilities/sidebar/layoutPicker),
hypr, toaster, gameMode, debug, lock (lock/unlock/isLocked), wallpaper,
brightness, mpris, colours, picker`.

Drawers (layer-shell, toggle via IPC): `bar, osd, session, launcher,
dashboard, utilities, sidebar, layoutPicker`.

Control Center panes (21, from `PaneRegistry.qml`): appearance, apps,
audio, bluetooth, build, companion, dashboard, launcher, layout, network,
notifications, osd, palette, power, raven, router, system, taskbar, tune,
updates, vpn.

Settings is a **floating Hyprland window** (`org.quickshell`, title
"Hornero Settings - \<Pane\>"), not a layer-shell drawer. Closed via WM
close (`hyprctl dispatch closewindow 'title:Hornero Settings.*'`),
`Escape` (window shortcut), or `qs ipc call controlCenter close`
(`WindowFactory.closeAll`). The dead empty `ControlCenter.qml close()`
stub was removed; the real close path is `WindowFactory` plus
`FloatingWindow` teardown.

## 2. Baseline screenshot set

| File | Surface | Notes |
|---|---|---|
| `desktop-idle.png` | idle desktop | left rail bar, wallpaper dimmed |
| `launcher.png` / `launcher-light.png` | launcher dark + light | coherent in both modes (§4) |
| `dashboard.png` | dashboard, Layout tab | bar-preset picker lives here |
| `cc-appearance.png` | Settings/Appearance | collapsed sections, live preview |
| `cc-system.png` | Settings/System | resources + quick actions |
| `cc-network.png` | Settings/Network | real devices, empty-state copy |
| `cc-audio.png` | Settings/Audio | sliders with numeric badges |
| `welcome.png` | lock screen (auto-lock fired mid-capture) | accidental but useful |
| `welcome-shortcuts.png` | Welcome/Shortcuts | 129 shortcuts, keycaps |
| `session.png` | session drawer | right-edge power menu |
| `companion.png` | Companion summoned | sprite over Settings window |
| `toast.png` | `toaster info` | bottom-right card |

Gaps (not yet captured): bar popouts, notification center/history,
bluetooth/vpn/updates/power panes, greeter, Pampa theme, HiDPI,
multi-monitor. To be covered in implementation slices.

## 3. Reference matrix (structure-level, via `gh api`, no clones)

| Dimension | Hornero (main) | Ryoku (`Ryoku-dev/ryoku`, GPL-3.0) | Caelestia (`caelestia-dots/shell`, GPL-3.0) | DMS (`AvengeMedia/DankMaterialShell`, MIT) |
|---|---|---|---|---|
| Settings IA | one window, 15 panes, nav rail | distro repo; shell under `ryoku/shell/quickshell` | **no settings module in shell**; config via `caelestia-cli` (separate repo) | **split**: `Settings/` tabbed window (`*Tab.qml`) + `ControlCenter/` popout (Widgets+Details) |
| Dashboard | tabs: Dashboard/Media/Performance/Weather/Workspaces/Layout | `ryoku/shell` has `welcome`, `keys`, `keys-hint`, `reload-cover`, `ryopin`, `ryoshot` | modules: bar/dashboard/launcher/lock/notifications/osd/session/sidebar/utilities/drawers/areapicker/background/windowinfo/**nexus** | `DankDash/` tabbed popout (Media, Notifications, Overview, Wallpaper, Weather tabs) |
| Launcher | centered panel, app list, `>` command mode | — (deeper read pending) | `launcher` module (deeper read pending) | `AppDrawer` module separate from dash |
| Onboarding | Welcome Center (Start/Navigate/Shell/Workspaces/Personalize/Tools/System/Learn/Shortcuts) | has `welcome` module | none in shell | `Greetd` module; onboarding via greeter |
| Backend boundary | `horneroctl` (V) + C++ natives + M3 python synthesizer | `rashin/backend`, `palette-bridge` | `caelestia` (framework) + `cli` | Go backend + `DankCommon` |
| Reload UX | reload cover | `reload-cover` module | — | — |

Lessons (concepts, not copies):

1. **DMS's Settings-vs-ControlCenter split** directly addresses Hornero's
   15-pane single-window scaling question. Hornero already separates
   drawers (quick) from Settings (full), but the Settings window keeps
   growing; a popout-vs-window rule would make the boundary principled.
2. **Caelestia's CLI-owned settings** is the far end of the same spectrum
   (no GUI settings at all). Hornero sits in the middle (GUI + horneroctl);
   keep both, keep them consistent (`appearance status` vs live mode gap
   in §5.4 shows the cost when they drift).
3. **Caelestia `nexus`** vs Hornero's dashboard tabs: both accumulate
   heterogeneous widgets; neither has an explicit role statement.
   A written role per surface is the fix, not a layout copy.
4. **Ryoku's `keys`/`keys-hint` + `welcome`** parallels Hornero's
   Welcome/Shortcuts + shortcut manifest. Same problem (keyboard
   discoverability), both solved in-product. Compare content quality,
   not layout.

Deliberately rejected (no evidence of need): plugin systems (Ryoku
`plugins/`, DMS `PLUGINS`, Caelestia `plugin/`), additional launcher
providers, dock layouts, copying any bar/sidebar geometry.

## 4. Design system audit (from live evidence)

- **Tokens**: M3-derived palette (`surfaceContainer*`, `onSurface*`,
  `primary*`, `outline*`) resolves coherently in **both** dark and light
  modes (`launcher.png` vs `launcher-light.png`: white cards, dark text,
  lavender accents, green Run/favorite states all legible). No hard-coded
  dark assumptions observed in launcher, Settings panes, session drawer,
  toast.
- **Typography**: single UI sans throughout; mono for keycaps, device
  names, resource values. Hierarchy is size/weight-based, consistent.
- **Keycaps**: `StyledText.mono` pills (SUPER/CTRL/ALT/SHIFT/F4/minus/
  apostrophe/comma/equal) — cozy and legible at 1080p.
- **Iconography**: Material Symbols for system actions; real app icons in
  launcher; pixel-art Companion sprite. No icon gaps observed in captured
  panes.
- **Motion**: not yet audited (needs screen recordings). Deferred to
  implementation slices; do not assume incoherence.
- **Wallpaper storage**: theme media is resolved through the installed Hornero
  catalogue and manifests; current wallpaper state belongs under the user XDG
  state directory.

## 5. UX problems (evidence-backed, with reproduction)

### 5.1 Settings has no programmatic close; `close()` is a stub

> **Fixed** (slice: companion yield PR, `WindowFactory` suppression
> work): `qs ipc call controlCenter close` dismisses via
> `WindowFactory.closeAll`, `Escape` closes the window, and the dead
> empty `ControlCenter.qml close()` stub was removed. Original finding
> kept below for the record.

`ControlCenter.qml:28` — `function close(): void {}` (empty). The only IPC
verb is `controlCenter open <pane>`. Dismissal today requires WM close
(X button / `hyprctl closewindow`). Any keyboard-first or scripted flow
that opens Settings cannot close it. Repro: `qs ipc call controlCenter
open appearance`, then no IPC call dismisses it.

### 5.2 Lock screen shows full notification content

`welcome.png` (accidental lock capture): "14 notifications" with complete
bodies ("Smart Float Window: 1400x864" x14) visible pre-auth. Privacy gap:
notification content on lock screen should be hidden or redacted by
default.

### 5.3 Welcome Shortcuts exposes raw compositor internals

`welcome-shortcuts.png`, Windows group: "Centerwindow unnamed",
"Killactive unnamed", "Layoutmsg fit active", "Layoutmsg colresize conf".
These are Hyprland dispatcher names, not user actions. A new user cannot
map them to intent. The manifest is authoritative for bindings; the
*labels* need a human-readable layer.

### 5.4 `horneroctl appearance status` disagrees with live shell

After `appearance theme apply hornero-light --yes`: `colours mode` →
`light`, launcher rendered light, but `appearance status` still reported
`mode: dark`. State file vs live shell drift. (Restored to dark/dark
after capture; both agree again.)

### 5.5 Wallpaper filenames truncate to unreadability

`cc-appearance.png`: `wallhaven-...0x1080.png` x6. Users cannot
distinguish wallpapers by name; thumbnails carry the whole burden.

### 5.6 Appearance sections all collapse by default

`cc-appearance.png`: Themes, Theme mode, Generation mode, Saved
palettes, GTK theme, GTK color scheme, Icon theme, Fonts, Animations,
Scales, Transparency — every section collapsed. First-run discoverability
relies entirely on Preview hover. No evidence yet whether state persists
per-section.

### 5.7 Companion renders above Settings windows

`companion.png`, `cc-audio.png`: summoned Companion sprite paints over
the floating Settings window. Z-order policy for Companion vs windows is
undefined (or explicitly always-on-top — either way, undocumented).

### 5.8 Session drawer avatar block is unexplained

`session.png`: an anime character tile sits between "Shut down" and
"Hibernate" in the power menu with no label. Origin (user avatar?
Companion skin? placeholder?) unknown — needs code read before judging.

## 6. Information architecture audit (current, descriptive)

- **Launcher**: app search + favorites + `>` command mode. Role: *do*.
  Clear.
- **Dashboard**: tabs Dashboard/Media/Performance/Weather/Workspaces.
  Role: *glance + switch*. (The former Layout tab — presets are
  Settings-grade configuration, not glanceable status — was removed
  by ADR 003; presets live in the drawer picker + Settings layout
  pane.)
- **Control Center ("Hornero Settings")**: 15 panes mixing **state**
  (network, audio, system resources) and **configuration** (appearance,
  taskbar, OSD). No in-window search observed. Scales by rail growth.
- **Welcome**: 9 sections incl. Shortcuts reference. Role: *learn*.
  Overlaps Dashboard (shortcuts lived there until #58/#59) — resolved by
  moving cheatsheet to Welcome, but Welcome length vs progressive
  disclosure unevaluated.
- **Sidebar / utilities / toaster / OSD / session / lock / Companion**:
  captured partially; roles look coherent, full audit pending per slice.

## 7. Experience principles (draft, to be ratified by evidence)

1. **State and configuration separate**: live state (connected, volume,
   resources) vs persisted configuration (themes, layouts) should never
   share a pane without a visual rule.
2. **Every surface states its role**: if Dashboard holds Layout presets,
   the reason must be written down, or the preset must move.
3. **No raw internals in user copy**: dispatcher names, file names,
   state keys get a human label before reaching pixels.
4. **Keyboard flows round-trip**: anything opened by keyboard/IPC must be
   closable the same way (5.1).
5. **Lock screen is a privacy boundary** (5.2), not a dashboard mirror.
6. **horneroctl and shell never disagree** about visible state (5.4);
   one source of truth with a sync verb, or one store.
7. **Hornero stays Hornero**: warm/earth identity, bird/nest/landscape
   cues, tasteful Argentine personality; no reference cloning (§3).

## 8. Proposed target experience (directional, not a spec)

A Hornero where: Settings keeps its two-column rail but gains a
popout-vs-window rule (quick state in drawers/popouts, durable
configuration in the window); Welcome Shortcuts labels every binding in
human language; lock screen redacts notification bodies; every drawer and
window dismisses from keyboard; Dashboard's Layout tab either justifies
itself in writing or moves to Settings; light mode stays first-class
(already is); Companion z-order is documented and predictable.

> Status 2026-09-30: several §8 items have since landed — central
> drawer Escape (S3, PR #75), Settings single-window reuse + Escape
> (#62), lock notification privacy default (#63), readable shortcut
> labels (#64), companion z-order (#69), dashboard Layout-tab removal
> (ADR 003). This section stays as the directional vision.

## 9. Implementation map (slices, each a small PR with before/after)

| # | Slice | Repo | Evidence |
|---|---|---|---|
| 1 | Settings keyboard/IPC close (fix 5.1) | shell | this doc |
| 2 | Lock-screen notification privacy (5.2) | shell | `welcome.png` |
| 3 | Human-readable shortcut labels (5.3) | shell + config manifest | `welcome-shortcuts.png` |
| 4 | Appearance state sync (5.4) | hornero (horneroctl) | §5.4 repro |
| 5 | Wallpaper name affordance (5.5) | shell | `cc-appearance.png` |
| 6 | Companion z-order policy (5.7) + session avatar read (5.8) | shell | `companion.png`, `session.png` |
| 7 | Dashboard Layout-tab role decision (ADR) | shell (`docs/adr/`) | `dashboard.png` |
| 8 | Greeter/website/docs coherence pass | greeter/website/docs | pending capture |

Dotfiles gap map, motion audit, viewport/HiDPI matrix, and installer
handoff remain open research items and will land as appendices before
their slices.

## 10. Validation plan

Per slice: implement → `horneroctl shell restart --yes` → interact →
`qs ipc` + `grim` capture → compare with `/tmp/hornero-baseline/` →
iterate. Gates unchanged: `pytest tests/ --ignore=tests/vm` (172 green
at baseline), `lint_qml.sh`, `check_forbidden_paths.sh`, full CI per PR.
No release cut until slices land; Preview 4 stays immutable.

## 11. External product comparison — 2026-10-12

This section extends the structure-level shell comparison with a current
review of the official repositories and published documentation for
[Caelestia](https://github.com/caelestia-dots),
[Ryoku](https://github.com/Ryoku-dev/ryoku), and
[Omarchy](https://github.com/omacom/omarchy). It records publicly
documented product structure, not a benchmark or a claim that every
feature was run locally. Details can change; links point to the reviewed
upstream sources.

| Product | Product shape visible in official sources | Notable user/contributor experience | HorneroOS lesson |
|---|---|---|---|
| Caelestia | A Quickshell desktop plus a separately distributed CLI/control script, framework/config repository, website, example plugin and official plugin manifests. The shell README positions it as a Hyprland-oriented desktop. | The CLI exposes shell, scheme, wallpaper, screenshot, recording, clipboard and install/update commands; its README documents configuration and installation. Themes can be generated from Material You color roles. | Keep command-line operations discoverable and documented alongside the GUI. Hornero's V horneroctl and graphical Settings can complement one another, provided status and writes share an explicit contract. The plugin validator merged in #155/#163 is a safer foundation than an undocumented extension directory; it does not by itself imply a plugin store or runtime loader. |
| Ryoku | A single Arch workstation distribution repository contains its desktop, system definition, installer, release/update system and CLI. It supports Hyprland and Niri in the compositor's native configuration languages. The wider organization includes docs, community store, and separate desktop tools. | The project states an explicit design and operating philosophy, publishes hardware requirements and operational boundaries (for example UEFI and Secure Boot constraints), and presents one visual language across shell surfaces. | State product boundaries and hardware/support requirements in one obvious place. Preserve Hornero's separately owned repositories and edition manifests, but give users a concise map of which repository owns each layer and how maturity differs. |
| Omarchy | An Arch-based, opinionated desktop distribution with an extensive manual, CLI and theme workflow. Its docs distinguish trusted first-party themes from repository-installed themes and filter files that can execute code. It also maintains a theme registry with validation and generated previews. | The manual covers everyday use, configuration, troubleshooting, security and theme authoring. Theming documentation describes activation and precedence, while the registry gives a clear submit → validate → publish path. | Hornero can make its existing source-of-truth boundaries easier for users and contributors to navigate: provide one theme-author guide, explain provenance and package ownership, and keep third-party extensions constrained and reviewable. Do not claim the plugin contract is equivalent to a curated marketplace. |

### Organization and repository boundaries

This inventory is based on the public organization listings and repository
metadata checked on 2026-10-12. A repository description is not proof of
maintenance ownership, compatibility, or release support; fork ancestry and
the repository's own documentation matter too.

| Ecosystem | Public repository map | Provenance and interpretation |
|---|---|---|
| Caelestia | The organization separates the Quickshell `shell`, the `cli`, the `caelestia` dotfiles/app-configuration repository, the `website`, official `plugins` manifests, and an `example-plugin`. | The CLI README describes the supported install/update path; the dotfiles repository marks its old `install.fish` as retired in favor of the CLI. Treat the plugin manifest repository and example as first-party extension infrastructure, not as evidence that arbitrary third-party QML is sandboxed. |
| Ryoku | The organization has the `ryoku` product repository, `ryoku-docs`, and `ryostore`, alongside repositories named `ryoshot`, `ryoview`, and `ryomotion`. | GitHub currently identifies `ryoshot` as a fork of [Gakuseei/rishot](https://github.com/Gakuseei/rishot), `ryoview` as a fork of [fedsfarm/gloview](https://github.com/fedsfarm/gloview), and `ryomotion` as a fork of [siddharthvaddem/openscreen](https://github.com/siddharthvaddem/openscreen). Their repository descriptions and README identities are not fully aligned. Compare their upstream projects and the Ryoku forks as distinct provenance; do not count the forks as original Ryoku implementations or assume the README describes a Ryoku-specific integration. |
| Omarchy | The `omarchy` repository contains the distribution, its manual, installer, CLI, theme workflow and operational documentation; `omarchy-theme-registry` separately publishes the community theme catalog. | The registry documents issue-based submission, automated validation, maintainer-reviewed merges, catalog builds, and preview publication. That is a concrete contribution pipeline; it remains separate from the first-party theme authoring and execution policy in Omarchy itself. |

The Ryoku fork metadata is especially useful when evaluating feature breadth:
the repositories indicate curated access to related tools, but their GitHub
parent links and upstream READMEs are necessary context before attributing
ownership or support. Recheck those relationships before using this comparison
for product or maintenance claims.

Hornero already exposes screenshot capture and recording through the Shell and
`horneroctl`, and has a static community-plugin contract and validator. Those
are not equivalent to a standalone annotation app, a workspace-switcher
product, or a theme marketplace. The meaningful follow-up is a reviewed
contribution path with explicit package ownership, provenance, preview
generation and lifecycle policy—not simply adding a directory of external
assets or claiming feature parity.

### Findings for HorneroOS

The comparison does not identify a missing feature that should be copied
verbatim. The products have different boundaries: Caelestia is a shell and
dotfiles ecosystem, Ryoku describes a complete workstation distribution,
and Omarchy couples a desktop distribution to a detailed user manual and
theme publishing workflow. HorneroOS is building a composable product
family across separate repositories, so its strongest opportunity is to
make those boundaries legible rather than imitate another repository
layout.

The work already present on HorneroOS main materially addresses several
of the useful patterns found in this review: a V-based management CLI,
edition/package composition, a shell plugin contract and validator, a
product design guide, a contributor-facing repository map, wallpaper
provenance, and an evidence-backed shell performance baseline. These are
product infrastructure, not proof that every planned edition or
compositor is fully supported. The website and docs should continue to
label release maturity according to the acceptance evidence for each
component.

The remaining high-value work is narrower:

1. **Publish one discoverable product map.** Link the design/brand guide,
   repository ownership map, contributor guide, supported editions, and
   compositor capability matrix from the website and organization profile.
   Keep the detailed specifications in their canonical repositories.
2. **Close the user documentation loop.** For each supported shell surface,
   document the user task, keyboard path, settings/CLI equivalent, and
   graceful behavior when an optional capability is unavailable. Keep
   Hyprland and Niri differences explicit instead of promising parity.
3. **Keep extension distribution separate from execution.** The plugin
   contract and validator establish format and static checks. A catalog,
   installer, signature/trust model, update behavior, and permissions
   policy would be separate product work and should not be implied until
   implemented.
4. **Measure live interaction before polishing timing.** Issue #77 records
   a small rapid-Escape race in nested Hyprland, with normal-speed closes
   succeeding and no crash/protocol failure. Quickshell 0.3.1 documents
   that HyprlandFocusGrab.active stays false until the compositor starts
   the grab, then becomes true; it also exposes cleared, but no signal for
   an Escape event missed before activation. A fix therefore needs a
   separate, non-invasive way to receive or preserve that key without
   stealing Escape from other applications. The existing VM harness can
   exercise real sessions only when explicitly run; its GitHub workflow
   intentionally validates scripts and dry-run coherence without booting a
   VM. Do not add arbitrary delays or claim the race fixed without
   repeatable before/after graphical evidence.

### Sources reviewed

- Caelestia [shell](https://github.com/caelestia-dots/shell),
  [CLI](https://github.com/caelestia-dots/cli), and
  [official plugin manifests](https://github.com/caelestia-dots/plugins).
- Quickshell 0.3.1
  [HyprlandFocusGrab reference](https://quickshell.org/docs/v0.3.1/types/Quickshell.Hyprland/HyprlandFocusGrab/).
- Ryoku [product repository](https://github.com/Ryoku-dev/ryoku),
  [documentation repository](https://github.com/Ryoku-dev/ryoku-docs), and
  [community store](https://github.com/Ryoku-dev/ryostore).
- Omarchy [product repository and manual](https://github.com/omacom/omarchy),
  [theme authoring guide](https://github.com/omacom/omarchy/blob/quattro/manual/43-making-your-own-theme.md),
  and [theme registry](https://github.com/omacom/omarchy-theme-registry).
