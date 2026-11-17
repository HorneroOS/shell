import qs.services
import QtQuick
import "../../services/clearink.js" as Model

// Tone of one foreground region of a Cockpit Clear bar (§12.1): the
// polarity-selected ink roles plus the halo/shadow parameters. `field`
// supplies the wallpaper grid; `target` is the region's item.
QtObject {
    id: root

    property var field: null
    required property Item target

    // Re-sampled when the grid, the style or the layout changes; layout
    // changes of any ancestor reach us through field.poke().
    readonly property var data: {
        if (!root.field)
            return Model.toneFor(null, ClearInk.style, Signal.light);
        root.field.revision;
        return Model.toneFor(root.field.statsFor(root.target), ClearInk.style, Signal.light);
    }

    readonly property Connections geometry: Connections {
        target: root.target

        function onXChanged(): void {
            root.field?.poke();
        }

        function onYChanged(): void {
            root.field?.poke();
        }

        function onWidthChanged(): void {
            root.field?.poke();
        }

        function onHeightChanged(): void {
            root.field?.poke();
        }
    }
    readonly property color ink: root.data.ink
    readonly property color inkMuted: root.data.inkMuted
    readonly property color signal: root.data.signal
    readonly property color alert: root.data.alert
    readonly property color halo: Qt.alpha(root.data.halo, root.data.haloAlpha)
    // The halo shader picks one of these per pixel from the foreground it
    // surrounds: dark behind light foreground, light behind dark.
    readonly property color haloOnLight: Model.LIGHT.halo
    readonly property color haloOnDark: Model.DARK.halo
    readonly property int weight: root.data.weight
    readonly property real offAlpha: root.data.offAlpha
    readonly property bool active: true
    readonly property var effect: Model.effectParams(root.data)
}
