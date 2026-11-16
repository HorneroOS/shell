pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell.Widgets
import QtQuick

// One launcher result as a command-line instrument row: a 28 px channel
// cell (app icon or glyph), the title in Plex Sans, detail in Plex Mono
// `inkMuted`, and a mono kind tag at the end. The current row carries the
// on-air bar on its leading edge plus a `raised` fill and shows the Enter
// key cue; colour is never the only signal.
Item {
    id: root

    property string iconSource: ""
    property string glyph: ""
    property string title: ""
    property string detail: ""
    property string kind: ""
    property int detailElide: Text.ElideRight
    property Component leading: null
    readonly property bool current: ListView.isCurrentItem
    signal activated

    implicitHeight: Config.launcher.sizes.itemHeight
    anchors.left: parent?.left
    anchors.right: parent?.right

    Accessible.role: Accessible.Button
    Accessible.name: root.detail !== "" ? `${root.title}, ${root.detail}` : root.title
    Accessible.onPressAction: root.activated()

    StateLayer {
        radius: Appearance.rounding.small

        function onClicked(): void {
            root.activated();
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: parent.height - 8
        color: Signal.palette.signal
        visible: root.current
    }

    Item {
        id: cell

        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28

        Loader {
            anchors.centerIn: parent
            active: root.leading !== null
            sourceComponent: root.leading
        }

        IconImage {
            anchors.centerIn: parent
            visible: root.leading === null && root.iconSource !== ""
            source: root.iconSource
            implicitSize: 24
            asynchronous: true
        }

        Glyph {
            anchors.centerIn: parent
            visible: root.leading === null && root.iconSource === "" && root.glyph !== ""
            name: root.glyph
            size: Appearance.font.size.large
            color: root.current ? Signal.palette.ink : Signal.palette.inkMuted
        }
    }

    Column {
        anchors.left: cell.right
        anchors.leftMargin: 12
        anchors.right: tail.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        StyledText {
            width: parent.width
            text: root.title
            font.pointSize: Appearance.font.size.normal
            font.weight: root.current ? Font.Medium : Font.Normal
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            visible: root.detail !== ""
            mono: true
            text: root.detail
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
            elide: root.detailElide
        }
    }

    Row {
        id: tail

        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.current
            mono: true
            text: "⏎"
            color: Signal.palette.signal
            font.pointSize: Appearance.font.size.small
            Accessible.ignored: true
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind !== ""
            mono: true
            text: root.kind
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Appearance.font.size.small * 0.08
            Accessible.ignored: true
        }
    }
}
