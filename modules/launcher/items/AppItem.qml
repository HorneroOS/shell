import "../services"
import qs.components
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick

LauncherRow {
    id: root

    required property DesktopEntry modelData
    required property PersistentProperties visibilities
    readonly property bool favourite: modelData ? Strings.testRegexList(Config.launcher.favouriteApps, modelData.id) : false

    iconSource: Quickshell.iconPath(root.modelData?.icon, "image-missing")
    title: root.modelData?.name ?? ""
    detail: (root.modelData?.comment || root.modelData?.genericName) ?? ""
    kind: root.favourite ? qsTr("FAV") : ""

    onActivated: {
        Apps.launch(root.modelData);
        root.visibilities.launcher = false;
    }
}
