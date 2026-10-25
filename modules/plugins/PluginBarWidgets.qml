pragma ComponentBehavior: Bound

import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

// Bar placement for community plugins (M2 slice 2): renders every
// enabled plugin whose manifest declares `placement: "bar"` inside the
// bar's end group. Each plugin gets its own Loader, so a failing
// entrypoint is marked failed through the Plugins service and never
// takes the bar (or other plugins) down. Plugin QML runs with the
// logged-in user's permissions; it is NOT sandboxed.
Repeater {
    id: root

    required property bool vertical
    property bool surfaceActive: true

    model: surfaceActive ? Plugins.barPlugins() : []

    delegate: Loader {
        id: pluginLoader

        required property var modelData

        Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
        // Plugins cannot import Shell theming; give their default text the
        // bar's themed foreground through palette inheritance instead of
        // Qt's default black (invisible on the dark bar).
        palette.windowText: Colours.palette.m3onSurface
        source: modelData.entrypoint ? `file://${Plugins.pluginsDir}/${modelData.id}/${modelData.entrypoint}` : ""
        asynchronous: true

        onStatusChanged: {
            if (status === Loader.Ready)
                Plugins.markLoaded(modelData.id);
            else if (status === Loader.Error)
                Plugins.markFailed(modelData.id, "bar entrypoint failed to load (see shell log)");
        }
    }
}
