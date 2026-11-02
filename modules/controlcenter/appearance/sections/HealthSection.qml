pragma ComponentBehavior: Bound

import "../../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.config
import QtQuick
import QtQuick.Layouts

CollapsibleSection {
    id: root

    required property var session

    title: qsTr("Health & sync")
    description: qsTr("Appearance state, consistency check and palette sync")
    showBackground: true

    CtlCard {
        title: qsTr("Appearance status")
        description: qsTr("Wallpaper, mode, flavour and GTK/icon themes")
        probeArgv: ["horneroctl", "--json", "appearance", "status"]
        autoRun: true
    }

    CtlCard {
        title: qsTr("Appearance doctor")
        description: qsTr("Checks scheme, state, wallpaper and GTK consistency")
        probeArgv: ["horneroctl", "--json", "appearance", "doctor"]
        actionLabel: qsTr("Sync appearance")
        actionArgv: ["horneroctl", "--json", "appearance", "sync", "--yes"]
    }
}
