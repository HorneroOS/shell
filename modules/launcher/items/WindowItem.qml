import "../services"
import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Launcher window provider (shell#250 slice 1): `>win <query>` lists
// open windows from the compositor toplevels and focuses the chosen
// one through the Windows provider's activation (Hypr.dispatch, the
// shell's existing window-activation path). Hyprland-only today —
// the toplevel source is Hypr.toplevels; Niri rows arrive with its
// window read model.
Item {
    id: root

    required property var list
    required property var modelData

    function onClicked(): void {
        Windows.activate(root.modelData);
        root.list.visibilities.launcher = false;
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
            text: "web_asset"
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
                text: qsTr("%1 · workspace %2").arg(root.modelData?.appClass ?? "").arg(root.modelData?.workspaceName ?? "?")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
        }
    }
}
