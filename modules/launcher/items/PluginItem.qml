import "../services"
import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Plugin-defined provider row (shell#250 follow-up): one result
// from a hosted surfaces.launcher plugin. Activation goes through
// the registry (Providers.activate), which copies the plugin's
// result text with wl-copy and closes the launcher — the built-in
// calc provider's convention; plugins have no activation hook.
Item {
    id: root

    required property var list
    required property var modelData

    function onClicked(): void {
        Providers.activate(root.modelData, root.list);
    }

    implicitHeight: Config.launcher.sizes.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    Accessible.role: Accessible.Button
    Accessible.name: root.modelData?.title ?? ""

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
            text: root.modelData?.icon ?? "extension"
            font.pointSize: Appearance.font.size.extraLarge
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.modelData?.title ?? ""
                font.pointSize: Appearance.font.size.normal
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.modelData?.subtitle ?? ""
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }
    }
}
