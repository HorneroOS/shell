import qs.components
import qs.services
import qs.config
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property HyprlandToplevel client

    anchors.fill: parent
    spacing: Appearance.spacing.small

    Label {
        Layout.topMargin: Appearance.padding.large * 2

        text: root.client?.title ?? qsTr("No active client")
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere

        font.pointSize: Appearance.font.size.large
        font.weight: Appearance.font.weight.medium
    }

    Label {
        text: root.client?.lastIpcObject.class ?? qsTr("No active client")
        color: Signal.palette.phosphor

        font.pointSize: Appearance.font.size.larger
    }

    StyledRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.leftMargin: Appearance.padding.large * 2
        Layout.rightMargin: Appearance.padding.large * 2
        Layout.topMargin: Appearance.spacing.normal
        Layout.bottomMargin: Appearance.spacing.large

        color: Signal.palette.cue
    }

    Detail {
        icon: "map-pin"
        text: qsTr("Address: %1").arg(`0x${root.client?.address}` ?? "unknown")
        color: Signal.palette.signal
    }

    Detail {
        icon: "current-location"
        text: qsTr("Position: %1, %2").arg(root.client?.lastIpcObject.at[0] ?? -1).arg(root.client?.lastIpcObject.at[1] ?? -1)
    }

    Detail {
        icon: "resize"
        text: qsTr("Size: %1 x %2").arg(root.client?.lastIpcObject.size[0] ?? -1).arg(root.client?.lastIpcObject.size[1] ?? -1)
        color: Signal.palette.phosphor
    }

    Detail {
        icon: "layout-grid"
        text: qsTr("Workspace: %1 (%2)").arg(root.client?.workspace.name ?? -1).arg(root.client?.workspace.id ?? -1)
        color: Signal.palette.cue
    }

    Detail {
        icon: "device-desktop"
        text: {
            const mon = root.client?.monitor;
            if (mon)
                return qsTr("Monitor: %1 (%2) at %3, %4").arg(mon.name).arg(mon.id).arg(mon.x).arg(mon.y);
            return qsTr("Monitor: unknown");
        }
    }

    Detail {
        icon: "layout-navbar"
        text: qsTr("Initial title: %1").arg(root.client?.lastIpcObject.initialTitle ?? "unknown")
        color: Signal.palette.phosphor
    }

    Detail {
        icon: "category"
        text: qsTr("Initial class: %1").arg(root.client?.lastIpcObject.initialClass ?? "unknown")
    }

    Detail {
        icon: "hierarchy-2"
        text: qsTr("Process id: %1").arg(root.client?.lastIpcObject.pid ?? -1)
        color: Signal.palette.signal
    }

    Detail {
        icon: "picture-in-picture-on"
        text: qsTr("Floating: %1").arg(root.client?.lastIpcObject.floating ? "yes" : "no")
        color: Signal.palette.cue
    }

    Detail {
        icon: "gradienter"
        text: qsTr("Xwayland: %1").arg(root.client?.lastIpcObject.xwayland ? "yes" : "no")
    }

    Detail {
        icon: "pin"
        text: qsTr("Pinned: %1").arg(root.client?.lastIpcObject.pinned ? "yes" : "no")
        color: Signal.palette.cue
    }

    Detail {
        icon: "maximize"
        text: {
            const fs = root.client?.lastIpcObject.fullscreen;
            if (fs)
                return qsTr("Fullscreen state: %1").arg(fs == 0 ? "off" : fs == 1 ? "maximised" : "on");
            return qsTr("Fullscreen state: unknown");
        }
        color: Signal.palette.phosphor
    }

    Item {
        Layout.fillHeight: true
    }

    component Detail: RowLayout {
        id: detail

        required property string icon
        required property string text
        property alias color: icon.color

        Layout.leftMargin: Appearance.padding.large
        Layout.rightMargin: Appearance.padding.large
        Layout.fillWidth: true

        spacing: Appearance.spacing.smaller

        Glyph {
            id: icon

            Layout.alignment: Qt.AlignVCenter
            name: detail.icon
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: detail.text
            elide: Text.ElideRight
            font.pointSize: Appearance.font.size.normal
        }
    }

    component Label: StyledText {
        Layout.leftMargin: Appearance.padding.large
        Layout.rightMargin: Appearance.padding.large
        Layout.fillWidth: true
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        animate: true
    }
}
