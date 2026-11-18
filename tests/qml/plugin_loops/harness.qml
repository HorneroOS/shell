import "modules"
import "modules/companion"
import "modules/plugins"
import QtQuick
import QtQuick.Window
import Quickshell
import qs.services

// Binding-loop regression harness: the real plugin hosts (PluginHost,
// PluginLauncherHost, PluginDesktopWidgets, PluginBarWidgets) over the real
// Plugins service, fed by fixture plugins. Prints one PLOOPS line once every
// fixture has loaded so the test can tell a clean run from an empty one.
ShellRoot {
    PluginHost {}
    PluginLauncherHost {}

    Window {
        visible: true
        width: 1920
        height: 1080

        PluginDesktopWidgets {
            anchors.fill: parent
            screenName: "OFF-1"
        }
        Row {
            PluginBarWidgets {
                section: "actions"
                vertical: false
                thickness: 40
            }
        }
    }

    Timer {
        interval: 12000
        running: true
        onTriggered: {
            console.log("PLOOPS " + JSON.stringify({
                mode: Experience.mode,
                deck: Plugins.deckPlugins().length,
                bar: Plugins.barPlugins().length,
                launcher: Plugins.launcherPlugins().length,
                states: Plugins.entries.map(e => e.id + ":" + e.state)
            }));
            Qt.quit();
        }
    }
}
