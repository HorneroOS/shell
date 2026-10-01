import qs.components
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Pinned applications (legacy dock-bottom shortcuts). options.apps lists
// desktop-entry ids; entries are resolved and launched through
// DesktopEntries, never through command strings in the preset.
Item {
    id: root

    property bool vertical
    property var options: ({})
    readonly property var apps: {
        const ids = Array.isArray(options.apps) ? options.apps : [];
        const out = [];
        for (const id of ids) {
            const entry = DesktopEntries.heuristicLookup(id);
            if (entry)
                out.push(entry);
        }
        return out;
    }

    visible: apps.length > 0
    implicitWidth: visible ? layout.implicitWidth : 0
    implicitHeight: visible ? layout.implicitHeight : 0

    GridLayout {
        id: layout

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: Appearance.spacing.smaller
        columnSpacing: Appearance.spacing.smaller

        Repeater {
            model: root.apps

            BarButton {
                required property var modelData

                iconSource: Quickshell.iconPath(modelData.icon, "application-x-executable")
                label: modelData.name
                iconSize: Appearance.font.size.normal
                onActivated: modelData.execute()
            }
        }
    }
}
