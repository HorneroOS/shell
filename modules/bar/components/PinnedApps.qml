import qs.components
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Pinned application shortcuts. options.apps lists
// desktop-entry ids; entries are resolved and launched through
// DesktopEntries, never through command strings in the preset.
Item {
    id: root

    property bool vertical
    property var options: ({})
    readonly property var apps: {
        // Read .values instead of calling heuristicLookup alone: the entry
        // database populates asynchronously and .values notifies when it
        // lands, so pins resolve after startup instead of staying empty.
        // See QuickActions: options arrays need toArray(), not Array.isArray.
        const byId = {};
        for (const e of Config.bar.toArray(DesktopEntries.applications.values)) {
            byId[e.id] = e;
            if (e.id.endsWith(".desktop"))
                byId[e.id.slice(0, -8)] = e;
        }
        const out = [];
        for (const id of Config.bar.toArray(options.apps)) {
            const entry = byId[id] ?? DesktopEntries.heuristicLookup(id);
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
