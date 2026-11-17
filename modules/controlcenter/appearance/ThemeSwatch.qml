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
Well {
    id: root

    property var palette: ({
    })

    function role(name: string) : color {
        return root.palette[name] ?? Signal.palette[name];
    }

    implicitWidth: 124
    implicitHeight: 52
    color: root.role("ground")
    outline: root.role("ruleStrong")
    clip: true
    Accessible.ignored: true

    Rectangle {
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
        x: 88
        y: 6
        width: 30
        height: 10
        radius: 2
        color: root.role("sunken")
        border.width: 1
        border.color: root.role("rule")
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1
        height: 14

        Repeater {
            model: ["sunken", "raised", "signal", "cue", "phosphor", "alert"]

            Rectangle {
                required property string modelData

                width: (parent.width) / 6
                height: parent.height
                color: root.role(modelData)
            }

        }

    }

}
