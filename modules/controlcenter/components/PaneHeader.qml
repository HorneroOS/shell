pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import qs.modules.controlcenter
import QtQuick
import QtQuick.Layouts

// Shared page header for Control Center panes (shell#454): the pane icon and
// title, its one-line description, and — for panes whose purpose is not
// obvious — a short plain-language introduction in a soft card. Every pane
// opens the same way, so the window reads as one app.
ColumnLayout {
    id: root

    // With paneId, title, icon and description come from PaneRegistry, so the
    // rail, search and page header always agree (shell#460).
    property string paneId: ""
    readonly property var registryPane: root.paneId.length > 0 ? PaneRegistry.getById(root.paneId) : null
    property string title: root.registryPane?.title ?? ""
    property string icon: root.registryPane?.icon ?? ""
    property string description: root.registryPane?.description ?? ""
    property string intro: ""

    // Channel eyebrow (`07 · LOOK & FEEL`): the pane's position in the
    // registry and its settings category, so the rail, search and header
    // agree on where a pane lives (signal-visual-language §7.1).
    readonly property int channelIndex: root.paneId.length > 0 ? PaneRegistry.getIndexByLabel(root.registryPane?.label ?? "") : -1
    readonly property string channel: root.channelIndex >= 0 ? String(root.channelIndex + 1).padStart(2, "0") : ""
    readonly property string category: root.registryPane ? PaneRegistry.categoryTitle(root.registryPane.category) : ""

    Layout.fillWidth: true
    spacing: Appearance.spacing.small

    Eyebrow {
        Layout.fillWidth: true
        visible: root.category.length > 0
        channel: root.channel
        label: root.category
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        Glyph {
            visible: root.icon.length > 0
            name: root.icon
            font.pointSize: Appearance.font.size.extraLarge
            color: Signal.palette.signal
        }

        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: 600
            elide: Text.ElideRight
            Accessible.role: Accessible.Heading
        }
    }

    StyledText {
        visible: root.description.length > 0
        Layout.fillWidth: true
        text: root.description
        font.pointSize: Appearance.font.size.normal
        color: Signal.palette.inkMuted
        wrapMode: Text.WordWrap
    }

    Hairline {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.small
    }

    Well {
        visible: root.intro.length > 0
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.small
        implicitHeight: introRow.implicitHeight + Appearance.padding.large * 2
        color: Signal.palette.sunken

        RowLayout {
            id: introRow

            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.normal

            Glyph {
                Layout.alignment: Qt.AlignTop
                name: "info-circle"
                color: Signal.palette.cue
            }

            StyledText {
                Layout.fillWidth: true
                text: root.intro
                wrapMode: Text.WordWrap
                color: Signal.palette.ink
            }
        }
    }
}
