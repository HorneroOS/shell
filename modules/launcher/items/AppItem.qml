import "../services"
import qs.components
import qs.modules.apps
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick

LauncherRow {
    id: root

    required property var modelData
    required property PersistentProperties visibilities
    readonly property bool isCatalog: !!(modelData && modelData.isCatalogEntry === true)
    readonly property bool favourite: !isCatalog && modelData ? Strings.testRegexList(Config.launcher.favouriteApps, modelData.id) : false

    iconSource: isCatalog ? (modelData.icon ? Quickshell.iconPath(modelData.icon, "application-x-executable") : "") : Quickshell.iconPath(root.modelData?.icon, "image-missing")
    glyph: isCatalog && !(modelData.icon) ? "apps" : ""
    title: root.modelData?.name ?? ""
    detail: isCatalog ? qsTr("Available in Hornero Apps · %1").arg(modelData.provenanceText || modelData.backendText || "") : ((root.modelData?.comment || root.modelData?.genericName) ?? "")
    kind: isCatalog ? (modelData.backendPill || qsTr("APP")) : (root.favourite ? qsTr("FAV") : "")

    onActivated: {
        if (root.isCatalog)
            AppsStore.open(root.modelData.id);
        else
            Apps.launch(root.modelData);
        root.visibilities.launcher = false;
    }
}
