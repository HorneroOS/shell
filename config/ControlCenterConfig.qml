import Quickshell.Io

JsonObject {
    property Sizes sizes: Sizes {}

    // How long the "Applied · Undo" strip stays up after a risky or slow
    // change (docs/CONTROL-CENTER-APPLY.md). 3 to 60 seconds.
    property real undoSeconds: 10

    // Shared trailing-action rail used by repeatable settings rows.
    readonly property real actionColumnWidth: 136

    // Appearance-pane section disclosure: keys of expanded sections.
    // Default exposes Themes (the primary first-run task); the pane
    // persists user toggles here via Config.save().
    property var appearanceOpenSections: ["themes"]

    // Appearance: pointing at (or focusing) a theme, wallpaper, colour
    // scheme or Chromatic variant previews it until the pointer leaves.
    // Off: nothing changes until you click (docs/APPEARANCE-PANE.md).
    property bool appearanceHoverPreview: true

    component Sizes: JsonObject {
        property real heightMult: 0.7
        property real ratio: 16 / 9
    }
}
