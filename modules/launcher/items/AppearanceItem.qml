pragma ComponentBehavior: Bound

import "../services"
import qs.components
import qs.services
import qs.config
import QtQuick

// Theme result: the leading cell is a Signal swatch strip built from the
// theme's own roles (ground, panel, ink, signal, cue) — no wallpaper
// thumbnail, no tonal variants.
LauncherRow {
    id: root

    required property Themes.Theme modelData
    required property var list
    readonly property var pal: root.modelData?.palette ?? ({})

    title: root.modelData?.name ?? ""
    detail: root.modelData?.description ?? ""
    kind: root.modelData?.id === Signal.themeId ? qsTr("ON") : ""
    onActivated: root.modelData?.onClicked(root.list)

    leading: Rectangle {
        width: 28
        height: 20
        radius: Appearance.rounding.small
        color: root.pal.ground ?? Signal.palette.ground
        border.width: 1
        border.color: Signal.palette.ruleStrong

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: ["ink", "signal", "cue", "phosphor"]

                Rectangle {
                    required property string modelData

                    width: 3
                    height: 10
                    color: root.pal[modelData] ?? "transparent"
                }
            }
        }
    }
}
