import "../services"
import qs.components
import qs.services
import qs.config
import QtQuick

// Built-in clipboard history row (HorneroOS/shell#737): copies the selected
// entry back to the clipboard via Clipboard.copyText (wl-copy stdin) and
// closes the launcher.
LauncherRow {
    id: root

    required property var list
    required property var modelData

    function onClicked(): void {
        const text = root.modelData?.text ?? "";
        if (text.length > 0)
            Clipboard.copyText(text);
        root.list.visibilities.launcher = false;
    }

    glyph: "clipboard"
    title: root.modelData?.preview ?? ""
    detail: Clipboard.formatMeta(root.modelData)
    kind: qsTr("COPY")
    onActivated: root.onClicked()
}
