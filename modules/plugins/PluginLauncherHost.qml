pragma ComponentBehavior: Bound

import qs.modules.launcher.services
import qs.services
import Quickshell
import QtQuick

// Launcher plugin host (shell#250 follow-up, completing the
// surfaces.launcher hosting reserved in shell#373): for every
// enabled, installed plugin declaring surfaces.launcher, load its
// entrypoint in a hidden Loader and register it into the launcher
// provider registry (modules/launcher/services/Providers.qml).
//
// Established contract, shipped by the HorneroOS/plugins utility
// packages (e.g. hornero-calculator/Launcher.qml) and NOT invented
// here: the entrypoint root Item exposes a settable string
// property `query` and a readonly var property `result` shaped
// { ok: bool, text: string }. This host sets query and reads
// result; there is no plugin activation hook, so activation
// copies result.text with wl-copy, the built-in calc provider's
// convention (see docs/LAUNCHER.md).
//
// Fault isolation: each plugin gets its own asynchronous Loader.
// Loader.Error marks only that plugin failed through the Plugins
// service (Plugins.markFailed); the launcher, the registry and
// other providers are untouched. An entrypoint missing the
// query/result contract is skipped with a diagnostic
// (launcher-contract-missing) and never registered — it does not
// fail the plugin's other surfaces. Disabling a plugin (or safe
// mode, which empties pluginsForSurface) destroys its delegate,
// which unregisters the provider and unloads the Loader.
//
// Registration happens only after the built-in providers have
// registered (Providers.builtinsRegistered), and the registry
// rejects duplicate ids/prefixes, so a built-in prefix always
// wins a collision; a rejected plugin registration is logged as
// launcher-registration-rejected and simply never routes.
//
// Honest trust note: plugin QML runs in-process as your user,
// unsandboxed — the same trust as every other plugin surface.
// This host is not a permission boundary.
Item {
    id: root

    visible: false

    Repeater {
        model: Plugins.launcherPlugins()

        delegate: Item {
            id: slot

            required property var modelData
            readonly property string pluginId: modelData.id
            readonly property string displayName: typeof modelData.name === "string" && modelData.name !== "" ? modelData.name : modelData.id
            readonly property string icon: typeof modelData.icon === "string" && modelData.icon !== "" ? modelData.icon : "extension"
            readonly property string prefix: Providers.launcherPrefixFor(modelData.id)
            property bool registered: false

            function unregister(): void {
                if (slot.registered) {
                    Providers.unregisterProvider(slot.pluginId);
                    slot.registered = false;
                }
            }

            function tryRegister(): void {
                const item = pluginLoader.item;
                if (slot.registered || !item || pluginLoader.status !== Loader.Ready)
                    return;
                if (!Providers.builtinsRegistered)
                    return;
                if (!Providers.launcherContractOk(item)) {
                    Plugins.logDiagnostic(slot.pluginId, "launcher-contract-missing", "launcher entrypoint must expose a settable string 'query' and a readonly var 'result' shaped {ok: bool, text: string}; provider not registered");
                    return;
                }
                const ok = Providers.registerProvider({
                    "id": slot.pluginId,
                    "prefix": slot.prefix,
                    "icon": slot.icon,
                    "section": slot.pluginId,
                    "query": text => {
                        const hosted = pluginLoader.item;
                        if (!hosted)
                            return [];
                        try {
                            hosted.query = text;
                        } catch (e) {
                            return [];
                        }
                        const row = Providers.launcherRow(slot.pluginId, slot.displayName, slot.icon, hosted.result);
                        return row ? [row] : [];
                    },
                    "activate": (result, list) => {
                        // No plugin activation hook exists in the
                        // contract: copy the result text, exactly
                        // like the built-in calc provider row
                        // (wl-copy via Quickshell.execDetached).
                        if (result && result.payload && typeof result.payload.text === "string" && result.payload.text !== "")
                            Quickshell.execDetached(["wl-copy", result.payload.text]);
                        if (list)
                            list.visibilities.launcher = false;
                    }
                });
                slot.registered = ok;
                if (ok)
                    Plugins.logDiagnostic(slot.pluginId, "launcher-registered", `prefix "${slot.prefix}"`);
                else
                    Plugins.logDiagnostic(slot.pluginId, "launcher-registration-rejected", `id "${slot.pluginId}" or prefix "${slot.prefix}" is already registered (built-in providers win)`);
            }

            Component.onDestruction: slot.unregister()

            Connections {
                target: Providers

                function onBuiltinsRegisteredChanged(): void {
                    slot.tryRegister();
                }
            }

            Loader {
                id: pluginLoader

                active: true
                source: `file://${Plugins.pluginsDir}/${slot.pluginId}/${slot.modelData.entrypoint}`
                asynchronous: true

                onStatusChanged: {
                    if (status === Loader.Ready)
                        slot.tryRegister();
                    else if (status === Loader.Error) {
                        slot.unregister();
                        Plugins.markFailed(slot.pluginId, pluginLoader.errorString || "launcher entrypoint failed to load (see shell log)");
                    }
                }
            }
        }
    }
}
