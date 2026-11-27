import "../services"
import qs.components
import qs.services
import qs.config
import QtQuick

// Built-in emoji picker row (HorneroOS/shell#737): copies the selected
// character via Emoji.activate (Clipboard.copyText) and closes the launcher.
LauncherRow {
    id: root

    required property var list
    required property var modelData

    function onClicked(): void {
        Emoji.activate(root.modelData);
        root.list.visibilities.launcher = false;
    }

    leading: Component {
        StyledText {
            text: root.modelData?.char ?? ""
            font.pointSize: Appearance.font.size.large
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }
    }
    title: root.modelData?.name ?? ""
    detail: root.modelData?.category ?? ""
    kind: qsTr("COPY")
    onActivated: root.onClicked()
}
