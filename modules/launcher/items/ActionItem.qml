import "../services"
import qs.components
import qs.services
import qs.config
import QtQuick

LauncherRow {
    id: root

    required property var modelData
    required property var list

    glyph: root.modelData?.icon ?? ""
    title: root.modelData?.name ?? ""
    detail: root.modelData?.desc ?? ""

    onActivated: root.modelData?.onClicked(root.list)
}
