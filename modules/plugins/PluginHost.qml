pragma ComponentBehavior: Bound

import qs.services
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

// Plugin runtime host (M2 slice 1): loads every enabled, installed
// community plugin entrypoint exactly once per discovery, each in its
// own Loader so a plugin that fails to compile or instantiate is
// marked failed and never takes the shell (or other plugins) down.
//
// Slice 1 is headless for `background` plugins (the default):
// entrypoints are instantiated under an invisible root. Plugins whose
// manifest declares `placement: "bar"` are not loaded here; the bar
// renders them in its end group (modules/plugins/PluginBarWidgets.qml
// via modules/bar/Bar.qml). `placement: "dashboard"` plugins are
// rendered as cards by the dashboard Extensions tab
// (modules/plugins/PluginDashboardCards.qml). Other placements are
// rejected.
// Plugin QML runs with full user privileges — see services/Plugins.qml
// for the trust label.
Scope {
    id: root

    Repeater {
        model: Plugins.entries.filter(e => e.enabled && e.installed)

        delegate: Item {
            id: slot

            required property var modelData
            readonly property string pluginDir: `${Plugins.pluginsDir}/${modelData.id}`
            property string entrypoint: ""
            property string placement: ""

            FileView {
                id: manifestView

                path: `${slot.pluginDir}/manifest.json`
                printErrors: false

                onLoaded: {
                    try {
                        const manifest = JSON.parse(manifestView.text());
                        if (manifest.id !== slot.modelData.id) {
                            Plugins.markFailed(slot.modelData.id, "manifest id does not match its directory");
                            return;
                        }
                        if (typeof manifest.entrypoint !== "string" || manifest.entrypoint.includes("..")) {
                            Plugins.markFailed(slot.modelData.id, "manifest entrypoint is not a safe relative path");
                            return;
                        }
                        const placement = typeof manifest.placement === "string" ? manifest.placement : "background";
                        if (placement !== "background" && placement !== "bar" && placement !== "dashboard") {
                            Plugins.markFailed(slot.modelData.id, "manifest placement must be background, bar or dashboard");
                            return;
                        }
                        slot.placement = placement;
                        Plugins.markPlacement(slot.modelData.id, placement, manifest.entrypoint);
                        slot.entrypoint = manifest.entrypoint;
                    } catch (e) {
                        Plugins.markFailed(slot.modelData.id, "manifest.json is not readable JSON");
                    }
                }

                onLoadFailed: Plugins.markFailed(slot.modelData.id, "manifest.json could not be read")
            }

            Loader {
                id: pluginLoader

                active: slot.entrypoint !== "" && slot.placement !== "bar" && slot.placement !== "dashboard"
                source: active ? `file://${slot.pluginDir}/${slot.entrypoint}` : ""
                asynchronous: true

                onStatusChanged: {
                    if (status === Loader.Ready)
                        Plugins.markLoaded(slot.modelData.id);
                    else if (status === Loader.Error)
                        Plugins.markFailed(slot.modelData.id, "entrypoint failed to load (see shell log)");
                }
            }
        }
    }

    IpcHandler {
        target: "plugins"

        function status(): string {
            return JSON.stringify(Plugins.status());
        }

        function reload(): void {
            Plugins.reload();
        }
    }
}
