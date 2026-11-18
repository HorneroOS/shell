pragma ComponentBehavior: Bound

import qs.modules.launcher.services
import qs.services
import Quickshell
import Quickshell.Io
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
// copies the row's text with wl-copy, the built-in calc provider's
// convention (see docs/LAUNCHER.md). The text is written to
// wl-copy's stdin, never passed in argv: plugin-supplied text cannot
// be read as a wl-copy option (e.g. a row text of "--clear") and does
// not show up in the process list. An entrypoint may expose a
// `results` array instead for several rows (additive, see
// launcherplugin.js).
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

    // Copy plugin row text to the clipboard through wl-copy's stdin.
    // One copier is shared by every plugin; a copy requested while the
    // previous one is still being handed over runs right after it, and
    // only the latest pending text is kept.
    function copyText(text: string): void {
        copier.pending = text;
        if (!copier.running)
            copier.begin();
    }

    Process {
        id: copier

        property string pending: ""
        property string sending: ""

        function begin(): void {
            copier.sending = copier.pending;
            copier.pending = "";
            copier.stdinEnabled = true;
            copier.running = true;
        }

        command: ["wl-copy"]
        stdinEnabled: true
        onStarted: {
            copier.write(copier.sending);
            copier.sending = "";
            // Closing stdin ends the paste data; wl-copy then serves it.
            copier.stdinEnabled = false;
        }
        onRunningChanged: {
            if (!copier.running && copier.pending !== "")
                copier.begin();
        }
    }

    StableList {
        id: stable

        source: Plugins.launcherPlugins()
    }

    Repeater {
        model: stable.list

        delegate: Item {
            id: slot

            required property var modelData
            readonly property string pluginId: modelData.id
            readonly property string displayName: typeof modelData.name === "string" && modelData.name !== "" ? modelData.name : modelData.id
            readonly property string icon: typeof modelData.icon === "string" && modelData.icon !== "" ? modelData.icon : "puzzle"
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
                    Plugins.logDiagnostic(slot.pluginId, "launcher-contract-missing", "launcher entrypoint must expose a settable string 'query' and either a readonly var 'results' list of {text, title?, subtitle?, glyph?} or a readonly var 'result' shaped {ok: bool, text: string}; provider not registered");
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
                        return Providers.launcherRows(slot.pluginId, slot.displayName, slot.icon, hosted);
                    },
                    "activate": (result, list) => {
                        // No plugin activation hook exists in the
                        // contract: copy the result text, exactly
                        // like the built-in calc provider row, but via
                        // wl-copy's stdin (root.copyText), never argv.
                        if (result && result.payload && typeof result.payload.text === "string" && result.payload.text !== "")
                            root.copyText(result.payload.text);
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
                source: Plugins.entrypointUrl(slot.pluginId, slot.modelData.entrypoint)
                asynchronous: true

                onStatusChanged: {
                    if (status === Loader.Loading) {
                        Plugins.markLoading(slot.pluginId);
                    } else if (status === Loader.Ready) {
                        slot.tryRegister();
                        Plugins.markLoaded(slot.pluginId, "launcher");
                    } else if (status === Loader.Error) {
                        slot.unregister();
                        Plugins.markFailed(slot.pluginId, Plugins.loaderError(pluginLoader.errorString, pluginLoader.source) || "launcher entrypoint failed to load (see shell log)", "launcher");
                    }
                }
            }
        }
    }
}
