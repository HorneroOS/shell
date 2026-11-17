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
    // Polarity role sets: the scheme's own `clearInk` block when a
    // Chromatic palette is live, else the fixed Night/Day sets. Only
    // foreground colours; Cockpit Clear never gains a fill from this.
    readonly property var sets: Config.appearance.highContrast ? Model.setsFrom(null) : Model.setsFrom(Signal.clearInk)
    readonly property string configuredStyle: Model.normaliseStyle(Config.bar.clearStyle)
    // User knobs (Bars > Clear text): shadow/outline strength, ring width and
    // the ink polarity ("auto" follows the wallpaper). High Contrast keeps
    // the ink as it is but never weakens the shadow below the factory value.
    readonly property var knobs: ({
            strength: Config.appearance.highContrast ? Math.max(1, Config.bar.clearInk.strength) : Config.bar.clearInk.strength,
            outline: Config.bar.clearInk.outline,
            polarity: Model.normalisePolarity(Config.bar.clearInk.polarity)
        })
    readonly property var polarities: Model.POLARITIES
    readonly property string configuredPolarity: Model.normalisePolarity(Config.bar.clearInk.polarity)

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

    function setKnob(name: string, value: var): void {
        if (name === "polarity")
            Config.bar.clearInk.polarity = Model.normalisePolarity(value);
        else if (name === "strength")
            Config.bar.clearInk.strength = Math.max(0, Math.min(1.5, value));
        else if (name === "outline")
            Config.bar.clearInk.outline = Math.max(0, Math.min(2, value));
        else
            return;
        Config.save();
    }

    function polarityLabel(name: string): string {
        switch (name) {
        case "light":
            return qsTr("Light");
        case "dark":
            return qsTr("Dark");
        default:
            return qsTr("Auto");
        }
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
