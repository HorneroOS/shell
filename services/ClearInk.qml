pragma Singleton

import qs.config
import QtQuick
import Quickshell
import "clearink.js" as Model

// Cockpit Clear foreground style and the neutral tone (signal-visual-
// language §12). The per-region sampling lives in
// components/clearink/ClearInkField.qml (one per clear bar); components
// outside a clear bar keep `neutral`, which is the plain Signal palette.
Singleton {
    id: root

    readonly property var styles: Model.STYLES
    // High Contrast always means the Contrast style (§12.3).
    readonly property string style: Config.appearance.highContrast ? "contrast" : Model.normaliseStyle(Config.bar.clearStyle)
    readonly property string configuredStyle: Model.normaliseStyle(Config.bar.clearStyle)

    // What bar components use when no region tone applies.
    readonly property QtObject neutral: QtObject {
        readonly property color ink: Signal.palette.ink
        readonly property color inkMuted: Signal.palette.inkMuted
        readonly property color signal: Signal.palette.signal
        readonly property color alert: Signal.palette.alert
        readonly property color halo: "transparent"
        readonly property int weight: Font.Normal
        readonly property real offAlpha: 1
        readonly property bool active: false
    }

    function setStyle(name: string): void {
        if (!Model.isStyle(name))
            return;
        Config.bar.clearStyle = name;
        Config.save();
    }

    function styleLabel(name: string): string {
        switch (name) {
        case "outline":
            return qsTr("Outline");
        case "shadow":
            return qsTr("Shadow");
        case "contrast":
            return qsTr("Contrast");
        default:
            return qsTr("Auto");
        }
    }
}
