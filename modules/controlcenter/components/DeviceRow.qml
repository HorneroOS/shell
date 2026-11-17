pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Selectable device row. The current device carries the on-air bar, the
// `signalWell` fill and the word DEFAULT, so it never relies on colour
// alone. `detail` is a real value read from the service (e.g. a node name);
// leave it empty when none exists.
Item {
    id: root

    property string label: ""
    property string detail: ""
    property string glyph: "devices"
    property bool current: false
    property string currentWord: qsTr("default")
    // Spoken suffix for the current device (", current output").
    property string currentSpoken: qsTr(", current")

    signal activated

    readonly property bool isFirst: root.parent && root.parent.children.length > 0 && root.parent.children[0] === root

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + Appearance.padding.normal * 2

    Accessible.role: Accessible.Button
    Accessible.name: (root.label || qsTr("Unknown")) + (root.current ? root.currentSpoken : "")

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: root.isFirst ? 0 : 1
        color: root.current ? Signal.palette.signalWell : "transparent"
    }

    Hairline {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: !root.isFirst
    }

    OnAirBar {
        edge: "left"
        active: root.current
    }

    Interactive {
        function onClicked(): void {
            root.activated();
        }
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.large
        spacing: Appearance.spacing.normal

        Glyph {
            Layout.minimumWidth: Appearance.font.size.extraLarge * 1.5
            Layout.preferredWidth: Appearance.font.size.extraLarge * 1.5
            Layout.maximumWidth: Appearance.font.size.extraLarge * 1.5
            name: root.glyph
            font.pointSize: Appearance.font.size.large
            color: root.current ? Signal.palette.onSignalWell : Signal.palette.inkMuted
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                maximumLineCount: 1
                text: root.label || qsTr("Unknown")
                color: root.current ? Signal.palette.onSignalWell : Signal.palette.ink
                font.weight: root.current ? 600 : 400
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.detail.length > 0
                elide: Text.ElideMiddle
                maximumLineCount: 1
                mono: true
                text: root.detail
                color: root.current ? Signal.palette.onSignalWell : Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
            }
        }

        StyledText {
            visible: root.current
            mono: true
            text: root.currentWord.toUpperCase()
            color: Signal.palette.onSignalWell
            font.pointSize: Appearance.font.size.small
            font.letterSpacing: Appearance.font.size.small * 0.08
            Accessible.ignored: true
        }
    }
}
