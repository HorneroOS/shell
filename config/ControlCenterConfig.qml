import Quickshell.Io

JsonObject {
    property Sizes sizes: Sizes {}

    // Appearance-pane section disclosure: keys of expanded sections.
    // Default exposes Themes (the primary first-run task); the pane
    // persists user toggles here via Config.save().
    property var appearanceExpandedSections: ["themes"]

    component Sizes: JsonObject {
        property real heightMult: 0.7
        property real ratio: 16 / 9
    }
}
