import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var client
    readonly property var info: Compositor.windowDetails(client)

    anchors.fill: parent
    spacing: Appearance.spacing.small

    Label {
        Layout.topMargin: Appearance.padding.large * 2

        text: root.info?.title ?? qsTr("No active client")
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere

        font.pointSize: Appearance.font.size.large
        font.weight: Appearance.font.weight.medium
    }

    Label {
        text: root.info?.appClass ?? qsTr("No active client")
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
        text: qsTr("Address: %1").arg(root.info?.address ?? "unknown")
        color: Signal.palette.signal
    }

    Detail {
        icon: "current-location"
        text: qsTr("Position: %1, %2").arg(root.info?.x ?? -1).arg(root.info?.y ?? -1)
    }

    Detail {
        icon: "resize"
        text: qsTr("Size: %1 x %2").arg(root.info?.width ?? -1).arg(root.info?.height ?? -1)
        color: Signal.palette.phosphor
    }

    Detail {
        icon: "layout-grid"
        text: qsTr("Workspace: %1 (%2)").arg(root.info?.workspaceName ?? -1).arg(root.info?.workspaceId ?? -1)
        color: Signal.palette.cue
    }

    Detail {
        icon: "device-desktop"
        text: {
            const d = root.info;
            if (d && d.monitorName)
                return qsTr("Monitor: %1 (%2) at %3, %4").arg(d.monitorName).arg(d.monitorId).arg(d.monitorX).arg(d.monitorY);
            return qsTr("Monitor: unknown");
        }
    }

    Detail {
        icon: "layout-navbar"
        text: qsTr("Initial title: %1").arg(root.info?.initialTitle ?? "unknown")
        color: Signal.palette.phosphor
    }

    Detail {
        icon: "category"
        text: qsTr("Initial class: %1").arg(root.info?.initialClass ?? "unknown")
    }

    Detail {
        icon: "hierarchy-2"
        text: qsTr("Process id: %1").arg(root.info?.pid ?? -1)
        color: Signal.palette.signal
    }

    Detail {
        icon: "picture-in-picture-on"
        text: qsTr("Floating: %1").arg(root.info?.floating ? "yes" : "no")
        color: Signal.palette.cue
    }

    Detail {
        icon: "gradienter"
        text: qsTr("Xwayland: %1").arg(root.info?.xwayland ? "yes" : "no")
    }

    Detail {
        icon: "pin"
        text: qsTr("Pinned: %1").arg(root.info?.pinned ? "yes" : "no")
        color: Signal.palette.cue
    }

    Detail {
        icon: "maximize"
        text: {
            const fs = root.info?.fullscreen ?? -1;
            if (fs >= 0)
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
