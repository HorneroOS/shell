import "../services"
import qs.components
import qs.services
import qs.config
import QtQuick

// Launcher file provider row (shell#250 slice 2, on the provider
// registry): one bounded, ranked file result shaped
// { providerId, section, icon, title, subtitle, payload }, where
// title is the file name and subtitle its parent path. Activation
// goes through the registry (Providers.activate), which opens the
// path with xdg-open, the shell's existing open-path convention.
LauncherRow {
    id: root

    required property var list
    required property var modelData
    readonly property string fileName: root.modelData?.title ?? root.modelData?.payload?.name ?? ""
    readonly property string parentPath: root.modelData?.subtitle ?? root.modelData?.payload?.parent ?? ""

    function onClicked(): void {
        Providers.activate(root.modelData, root.list);
    }

    glyph: root.modelData?.icon ?? "file-text"
    title: root.fileName
    detail: root.parentPath
    detailElide: Text.ElideMiddle
    onActivated: root.onClicked()
}
