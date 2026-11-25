# Companion Platform

Status: PluginKit 6 foundation. This document is the contract for
installable Hornero companions. It deliberately separates a character's
artwork and declarative behaviour from executable extension QML.

Javi remains the built-in flagship. Its existing runtime, state file,
Hermes bridge, Nest construction progress and user preferences are
legacy-owned by `CompanionStore`; the platform registers it as the
built-in character `hornero:javi` without moving or rewriting that
state.

## Domain model

### Character

A character is an independently identifiable definition supplied by a
package. The stable public identity is `<pluginId>:<characterId>`; the
built-in reserved identity is `hornero:javi`. A character definition
contains localized names and description, author/license provenance, a
static preview, canvas and anchor geometry, locomotion capabilities,
skins, optional habitat, optional personality options and the assistant
binding kinds it is compatible with. Compatibility is metadata only:
it grants no assistant access.

### Skin

A skin is a visual variation of one character. It owns complete
animation reels for that character. A missing action falls back only
inside the same skin (explicit fallback, then that skin's `idle`). It
never falls back to another skin or another character, so clothing and
identity cannot silently disappear or change species.

### Animation pack

Skins contain versioned semantic animations. Each animation is either
an ordered frame list or one sprite atlas. Frames carry optional
per-frame duration and layered images. The v1 semantic vocabulary is:

`idle`, `blink`, `look`, `greet`, `walk`, `move`, `appear`, `leave`,
`rest`, `sleep`, `talk`, `listen`, `think`, `work`, `approve`,
`celebrate`, `deny`, `worry`, `error`, `drag`, `peek`, plus the
motion-specific `hover`, `takeoff`, `fly`, `land`, `perch`, `hop`,
`preen`, `stretch`, `swim`, `climb`, `roll` and `burrow`.

A character declares locomotion capabilities separately from the
animations it actually ships. The host asks for a semantic action and
uses the skin's explicit fallback, then `idle`. It never invents a
missing action and never borrows frames from another character or
skin.

### Habitat, personality and assistant binding

A habitat is an optional static layered environment declared with the
character. A personality is declarative presentation data (traits,
tone and localized canned lines); it has no prompt, instruction,
tool or permission fields. An assistant binding belongs to an
instance, is chosen by the user, and defaults to `none`. Character
packages may declare binding compatibility, never credentials or an
active session.

### Instance

An instance is a user-created runtime occurrence of a character. It
has a stable id, character id, skin, enabled flag, monitor name,
normalised position, scale, habitat choice, selected accessories,
personality id, reaction opt-in and assistant binding kind. Instance
state is versioned independently from the legacy Javi snapshot.
Removing a package preserves instance records as unavailable rather
than deleting unrelated configuration.

## Data-only PluginKit 6 package

A companion package is an ordinary schemaVersion 3 plugin package
with `"pluginKit": 6`, `"dataOnly": true`, background placement and
one or more `contributes.companions` entries:

```json
{
  "schemaVersion": 3,
  "pluginKit": 6,
  "dataOnly": true,
  "id": "example-capi",
  "entrypoint": "Main.qml",
  "placement": "background",
  "contributes": {
    "companions": [
      {
        "id": "capi",
        "title": "Capi",
        "definition": "companions/capi/companion.json",
        "preview": "companions/capi/preview.png"
      }
    ]
  },
  "capabilities": {
    "processCommands": [],
    "networkHosts": [],
    "settings": {}
  }
}
```

The package still carries the canonical inert `Main.qml` required by
the existing lifecycle:

```qml
import QtQuick

Item {}
```

That file is a lifecycle placeholder, not character code. For a
validated data-only package the shell does **not** instantiate any
entrypoint or surface. It reads only the manifest and referenced
JSON/image assets and renders them with trusted native components.
Any extra QML file, executable, symlink, process command, network
host, provider, action, surface, setting or non-companion
contribution rejects the data-only classification.

This is not described as a sandbox for executable extensions. A
package that wants executable QML remains an ordinary PluginKit
extension under the existing unsandboxed trust label, and it does
not become safe by declaring companion artwork.

## Character definition v1

Each contribution points to one closed JSON document. Unknown fields
are rejected. The validator enforces, at minimum:

- safe package-relative paths, with every referenced file listed in
  the package `files` inventory;
- no remote asset references;
- PNG/WebP sprite assets only, real image signatures and dimensions;
- per-image, decoded-memory, frame-count, animation-duration and
  whole-package budgets;
- canvas/anchor bounds and finite geometry;
- at least one skin, a valid default skin, and an `idle` reel in
  every skin;
- closed semantic action, capability, personality and assistant-mode
  vocabularies;
- fallback references that remain inside the same skin;
- bounded localized strings and canned lines;
- no prompt, instruction, command, tool, URL-fetch or permission
  fields anywhere in the definition.

The runtime repeats a tolerant sanitization pass before registration.
A malformed character is omitted with a diagnostic; it cannot crash
the shell or degrade other companions.

## Runtime shape

```text
PluginHost (manifest admission, no entrypoint load for dataOnly)
        |
Plugins service (normalized contributions)
        |
CompanionRegistry (built-in descriptors + FileView definition loads)
        |
CompanionInstances (versioned user instances)
        |
DataCompanionHost (native PanelWindow per active instance/screen)
        |
CompanionFramePlayer (shared frame/atlas renderer)
```

Javi continues through `CompanionHost` and `CompanionStore` during
the migration. That is an adapter, not a second source of truth: the
registry exposes Javi as a built-in character, while all Javi
behaviour/settings remain legacy-owned. New generic code must not
duplicate Javi's chat, Hermes, Nest or reaction policy.

Generic instances reuse the same suppression inputs as Javi
(lock, fullscreen, Gaming, area picker and Control Center), one
visibility-gated animation timer per visible sprite, bounded image
decode sizes, and no timers when hidden, suppressed or disabled.

## Reactions and assistants

Existing reaction governance remains authoritative. A reaction is
routed to the primary Javi instance by default, to one explicitly
selected generic instance, or to none. It is never broadcast to every
companion. Kind, mode, source, quiet-hours, mute, cooldown and rate
limits are decided once before routing.

Assistant bindings are explicit per instance. Built-in Javi keeps the
existing Hermes bridge and approvals. A data-only package cannot
create a session, inject instructions, select tools or change
permissions. Future harness bindings must be implemented as trusted
shell/horneroctl contracts first, then exposed as binding kinds here.

## Migration

The legacy snapshot at `$XDG_STATE_HOME/hornero/companion/state.json`
is untouched. On first platform load, the instance store seeds one
non-rendered legacy record for `hornero:javi` so collection and
routing have a stable instance identity; all editable Javi settings
continue to read and write their existing keys. Generic instance
state lives in `instances.json` beside it. Both migrations are
idempotent and unknown/malformed records sanitize independently.

## Delivery stages

1. **Contract and decorative runtime (shipped, shell 1.3.7):**
   PluginKit 6 data-only validation, registry, persisted instances,
   native sprite rendering, Control Center collection controls,
   reference package, add-on contributions and the sprite import
   tool.
2. **Javi art program (shipped, shell 1.3.7):** the approved 2026
   generation rebuilt every skin through the deterministic derive
   pipeline; the illustrated clay-workshop Nest replaced the
   procedural final stage. Hero masters are registered candidates
   with provenance; frames-hi and contact previews regenerated.
3. **Habitats and interactions (shipped):** independent habitat
   surfaces with their own persisted positions, proximity greetings
   bounded per pair, add-on skins/habitats.
4. **Assistant bindings (configuration only — no runtime consumer
   yet):** per-instance binding preference (none/Hermes/Veasel),
   filtered by each character's `assistantCompatibility`. The
   preference is persisted, but nothing reads it at runtime today:
   Javi's Hermes bridge is the only live assistant path. Decorative
   companions never start a process and packages gain no privileges.
5. **Catalogue and website (shipped):** official Capi and Bitín
   data-only packages in the catalogue, authoring guide EN/ES, and
   the website living-platform section. Performance: one
   visibility-gated timer per sprite; measured on the dev host,
   the full demo shell (Javi + two generic companions + four
   packages) runs at ~820 MB RSS after startup, with companions
   suppressed (zero sprite work) while locked or hidden.

## Add-ons (PluginKit 6)

`contributes.companionAddons` extends a character **from the same
package** with new skins and/or a habitat, without duplicating the
character: `{id, title, forCharacter, definition}` where the
definition is `{schemaVersion: 1, character, skins?, habitat?}`.
Add-on skins must be new ids (identity conflicts are rejected by
the validator and dropped by the runtime sanitizer), animations
validate against the target canvas, and a habitat applies only
when the character has none. Cross-package add-ons are deferred.
The import path for existing sprite folders (Shimeji-style names
recognized) is `scripts/companion_import.py`, which emits a valid
data-only package plus unmapped-file diagnostics. A poses folder
(`poses.json` + single-frame stills) imports through
`scripts/companion_import_poses.py`: poses map onto the closed
action vocabulary (`cast`→`work`, `reading`→`look`, `happy`→`greet`,
`sad`→`worry`+`error`), `eyes`/`glow` metadata is reported and
dropped, and the caller must supply the real rights holder via
`--author`/`--license`/`--source`/`--attribution` — the converter
ships no artwork and the resulting package is published by the
rights holder, never bundled by HorneroOS.
