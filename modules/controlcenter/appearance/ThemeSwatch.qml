import QtQuick
import qs.components
import qs.config
import qs.services

// Signal swatch card face: a miniature desk drawn in the theme's own
// roles (ground, panel, ink, the amber on-air bar) over a strip of six role
// chips. `palette` is the theme's role table (complete or the registry's
// partial `swatch`); roles it does not name fall back to the live palette
// so a partial swatch never renders a missing colour. Decorative: the card
// names the theme.
//
// One component for every place the Appearance pane shows a palette:
//  - `palette`: role table (term0..term15 allowed, as Colour.flatten emits);
//  - `terminal`: optional 16-entry array (a scheme's `terminal`), used when
//    the palette carries no termN keys;
//  - `showTerminal`: add a strip of the six ANSI hues (term1..term6) under
//    the role chips. It only draws colours the data really carries: a
//    partial registry swatch has none, so the strip stays hidden rather
//    than borrowing the live terminal colours;
//  - `compact`: no miniature desk, just the role strip (ground, panel, ink,
//    signal, cue, phosphor, alert) and the optional terminal strip;
//  - `pending`: the palette is still being computed; draws an empty well.
Well {
    id: root

    property var palette: ({
    })
    property var terminal: []
    property bool showTerminal: false
    property bool compact: false
    property bool pending: false

    readonly property var roleStrip: ["ground", "panel", "ink", "signal", "cue", "phosphor", "alert"]
    readonly property var terminalStrip: [1, 2, 3, 4, 5, 6]

    function role(name: string) : color {
        return root.palette[name] ?? Signal.palette[name];
    }

    // The theme's own terminal colour, or "" when the data has none.
    function term(i: int) : string {
        const own = root.palette["term" + i];
        if (own)
            return own;
        return Array.isArray(root.terminal) && root.terminal[i] ? root.terminal[i] : "";
    }

    readonly property bool hasTerminal: root.showTerminal && !root.pending && root.term(1) !== ""
    readonly property real stripHeight: root.compact ? 10 : 8

    implicitWidth: 124
    implicitHeight: root.compact ? 16 + (root.hasTerminal ? 10 : 0) + 2 : 52 + (root.hasTerminal ? 8 : 0)
    color: root.role("ground")
    outline: root.role("ruleStrong")
    clip: true
    radius: Config.appearance.cozyChips ? Appearance.rounding.normal : Appearance.rounding.small
    Accessible.ignored: true

    Rectangle {
        visible: !root.compact && !root.pending
        x: 6
        y: 6
        width: 76
        height: 22
        radius: 2
        color: root.role("panel")
        border.width: 1
        border.color: root.role("rule")

        Rectangle {
            x: 6
            y: 6
            width: 36
            height: 2
            color: root.role("ink")
        }

        Rectangle {
            x: 6
            y: 12
            width: 22
            height: 2
            color: root.role("inkMuted")
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: root.role("signal")
        }

    }

    Rectangle {
        visible: !root.compact && !root.pending
        x: 88
        y: 6
        width: 30
        height: 10
        radius: 2
        color: root.role("sunken")
        border.width: 1
        border.color: root.role("rule")
    }

    Column {
        visible: !root.pending
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1

        Row {
            width: parent.width
            height: root.compact ? 16 : 14

            Repeater {
                model: root.compact ? root.roleStrip : ["sunken", "raised", "signal", "cue", "phosphor", "alert"]

                Rectangle {
                    required property string modelData

                    width: parent.width / (root.compact ? root.roleStrip.length : 6)
                    height: parent.height
                    color: root.role(modelData)
                }

            }

        }

        Row {
            visible: root.hasTerminal
            width: parent.width
            height: root.stripHeight

            Repeater {
                model: root.hasTerminal ? root.terminalStrip : []

                Rectangle {
                    required property int modelData

                    width: parent.width / root.terminalStrip.length
                    height: parent.height
                    color: root.term(modelData)
                }

            }

        }

    }

}
