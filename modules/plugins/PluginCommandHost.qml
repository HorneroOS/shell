pragma ComponentBehavior: Bound

import qs.modules.launcher.services
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

// Command host (RFC 0003 section 4.2, PluginKit 4): the extension-provided
// commands reachable from the launcher (`>do <text>`), from IPC and from key
// bindings. The list comes from manifests only (Plugins.commandList()), so
// listing and searching never run extension code. Each extension's
// `surfaces.commands` entrypoint is loaded on first use, synchronously and
// in its own Loader so a failure to compile or instantiate is that
// extension's failure (marked through the Plugins service, bounded and
// redacted), never the launcher's or another extension's. Commands run only
// on a user gesture: a launcher activation, or an explicit IPC call the
// person bound to a key or typed.
//
// Handler contract: the entrypoint root Item implements
// `function run(commandId: string, args: string): string` returning an empty
// string on success or a short error text. An exception counts as an error.
//
// Honest trust note: in-process QML running as your user, unsandboxed, the
// same trust as every other surface. This host is not a permission
// boundary and the Shell writes no key binding: the person owns it.
Item {
    id: root

    visible: false

    readonly property string providerId: "plugin-commands"
    readonly property string providerPrefix: "do"
    // Bounded argument string the host passes through untouched.
    readonly property int maxArgsLength: 512

    StableList {
        id: stable

        source: Plugins.commandPlugins()
    }

    // Slot per hosting extension, by id.
    function slotFor(pluginId: string): var {
        for (let i = 0; i < repeater.count; i++) {
            const slot = repeater.itemAt(i);
            if (slot && slot.pluginId === pluginId)
                return slot;
        }
        return null;
    }

    // Runs one command. Returns "" on success, or a short error. Used by the
    // launcher activation and the IPC handler.
    function run(pluginId: string, commandId: string, args: string): string {
        if (Plugins.hostingBlocked)
            return qsTr("Extensions are not running (safe mode or outdated PluginKit)");
        const known = Plugins.commandList().find(c => c.pluginId === pluginId && c.id === commandId);
        if (!known)
            return qsTr("Unknown command %1 of %2").arg(commandId).arg(pluginId);
        const slot = root.slotFor(pluginId);
        if (!slot)
            return qsTr("%1 is not hosting commands").arg(pluginId);
        const text = typeof args === "string" ? args.slice(0, root.maxArgsLength) : "";
        const error = slot.invoke(commandId, text);
        if (error !== "")
            Plugins.logDiagnostic(pluginId, "command-failed", `${commandId}: ${error}`);
        return error;
    }

    Repeater {
        id: repeater

        model: stable.list

        delegate: Item {
            id: slot

            required property var modelData
            readonly property string pluginId: modelData.id
            // Loaded on first invocation; stays loaded for the session.
            property bool wanted: false

            function invoke(commandId: string, args: string): string {
                slot.wanted = true;
                if (pluginLoader.status === Loader.Error)
                    return qsTr("Commands of %1 failed to load").arg(slot.pluginId);
                const item = pluginLoader.item;
                if (!item || typeof item.run !== "function")
                    return qsTr("%1 has no run() handler").arg(slot.pluginId);
                try {
                    const result = item.run(commandId, args);
                    return typeof result === "string" ? result.slice(0, 200) : "";
                } catch (e) {
                    return qsTr("Command raised an error: %1").arg(Plugins.sanitizeDetail(String(e)));
                }
            }

            Loader {
                id: pluginLoader

                active: slot.wanted
                asynchronous: false
                source: slot.wanted ? Plugins.entrypointUrl(slot.pluginId, slot.modelData.entrypoint) : ""

                onStatusChanged: {
                    if (status === Loader.Loading)
                        Plugins.markLoading(slot.pluginId);
                    else if (status === Loader.Ready)
                        Plugins.markLoaded(slot.pluginId, "commands");
                    else if (status === Loader.Error)
                        Plugins.markFailed(slot.pluginId, Plugins.loaderError(pluginLoader.errorString, pluginLoader.source) || "commands entrypoint failed to load (see shell log)", "commands");
                }
            }
        }
    }

    // Launcher: `>do <text>` lists matching commands of enabled extensions
    // (title, keywords, extension name); activating one runs it.
    Component.onCompleted: root.tryRegister()

    property bool registered: false

    function tryRegister(): void {
        if (root.registered || !Providers.builtinsRegistered)
            return;
        root.registered = Providers.registerProvider({
            "id": root.providerId,
            "prefix": root.providerPrefix,
            "icon": "command",
            "section": root.providerId,
            "query": text => root.search(text),
            "activate": (result, list) => {
                const payload = result?.payload;
                if (payload && typeof payload.pluginId === "string") {
                    const error = root.run(payload.pluginId, payload.id, "");
                    if (error !== "")
                        Quickshell.execDetached(["notify-send", "-a", "hornero-shell", "-u", "low", payload.title, error]);
                }
                if (list)
                    list.visibilities.launcher = false;
            }
        });
    }

    Connections {
        target: Providers

        function onBuiltinsRegisteredChanged(): void {
            root.tryRegister();
        }
    }

    // Matching rows, best first: title prefix, then title contains, then
    // keyword, then extension name. An empty query lists everything.
    function search(text: string): var {
        const needle = (text || "").trim().toLowerCase();
        const scored = [];
        for (const command of Plugins.commandList()) {
            const title = command.title.toLowerCase();
            let score = -1;
            if (needle === "")
                score = 1;
            else if (title.startsWith(needle))
                score = 4;
            else if (title.includes(needle))
                score = 3;
            else if (command.keywords.some(k => k.toLowerCase().includes(needle)))
                score = 2;
            else if (command.pluginName.toLowerCase().includes(needle))
                score = 1;
            if (score < 0)
                continue;
            scored.push({
                score: score,
                row: {
                    "providerId": root.providerId,
                    "section": root.providerId,
                    "icon": command.glyph,
                    "title": command.title,
                    "subtitle": command.description !== "" ? `${command.pluginName} · ${command.description}` : command.pluginName,
                    "payload": command
                }
            });
        }
        scored.sort((a, b) => b.score - a.score);
        return scored.map(item => item.row);
    }

    IpcHandler {
        target: "plugincommands"

        // JSON list of every command of enabled extensions.
        function list(): string {
            return JSON.stringify(Plugins.commandList());
        }

        // Run one command: `qs ipc call plugincommands run <pluginId> <commandId> [args]`.
        // Returns "ok" or a one-line error.
        function run(pluginId: string, commandId: string, args: string): string {
            const error = root.run(pluginId, commandId, args);
            return error === "" ? "ok" : error;
        }
    }
}
