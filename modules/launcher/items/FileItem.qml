import "../services"
import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Launcher file provider row (shell#250 slice 2, on the provider
// registry): one bounded, ranked file result shaped
// { providerId, section, icon, title, subtitle, payload }, where
// title is the file name and subtitle its parent path. Activation
// goes through the registry (Providers.activate), which opens the
// path with xdg-open, the shell's existing open-path convention.
Item {
    id: root

    required property var list
    required property var modelData

    readonly property string fileName: root.modelData?.title ?? root.modelData?.payload?.name ?? ""
    readonly property string parentPath: root.modelData?.subtitle ?? root.modelData?.payload?.parent ?? ""

    function onClicked(): void {
        Providers.activate(root.modelData, root.list);
    }

    implicitHeight: Config.launcher.sizes.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    Accessible.role: Accessible.Button
    Accessible.name: root.fileName

    StateLayer {
        radius: Appearance.rounding.normal

        function onClicked(): void {
            root.onClicked();
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.larger
        spacing: Appearance.spacing.normal

        MaterialIcon {
            text: root.modelData?.icon ?? "description"
            font.pointSize: Appearance.font.size.extraLarge
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.fileName
                font.pointSize: Appearance.font.size.normal
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.parentPath
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideMiddle
            }
        }
    }
}
