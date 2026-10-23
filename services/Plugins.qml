pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

// Community plugin runtime state (M2). horneroctl is the single writer
// of lifecycle state (install/enable/disable/remove); this service only
// discovers what is enabled and tracks load outcomes for the host.
//
// Trust label, stated once and never softened: enabled plugin QML runs
// inside Quickshell with the logged-in user's privileges. It is NOT
// sandboxed, and the static contract validator is not a security
// certification. Only enable plugins whose source you have reviewed.
Singleton {
    id: root

    // Entries: {id, name, version, enabled, installed, state, detail}
    // state: pending | loaded | failed | disabled
    property var entries: []
    property bool discovered: false
    property string buffer: ""

    readonly property string pluginsDir: `${Paths.data}/plugins`

    function reload(): void {
        root.buffer = "";
        listProcess.running = true;
    }

    function markPlacement(id: string, placement: string, entrypoint: string, settings: var): void {
        const next = root.entries.map(e => e.id === id ? Object.assign({}, e, {
            placement: placement,
            entrypoint: entrypoint,
            settings: settings && typeof settings === "object" && !Array.isArray(settings) ? settings : ({})
        }) : e);
        root.entries = next;
    }

    function hasPlacement(id: string, placement: string): bool {
        const entry = root.entries.find(e => e.id === id);
        return !!entry && entry.placement === placement && entry.enabled && entry.installed;
    }

    function settingDeclaration(id: string, key: string): var {
        const entry = root.entries.find(e => e.id === id);
        if (!entry || !entry.settings || typeof entry.settings !== "object")
            return null;

        const declaration = entry.settings[key];
        return declaration && typeof declaration === "object" ? declaration : null;
    }

    function barPlugins(): var {
        return root.entries.filter(e => e.enabled && e.installed && e.placement === "bar");
    }

    function dashboardPlugins(): var {
        return root.entries.filter(e => e.enabled && e.installed && e.placement === "dashboard");
    }

    function desktopPlugins(): var {
        return root.entries.filter(e => e.enabled && e.installed && e.placement === "desktop");
    }

    function markLoaded(id: string): void {
        root.setState(id, "loaded", "");
    }

    function markFailed(id: string, detail: string): void {
        root.setState(id, "failed", (detail ?? "").toString().slice(0, 200));
        console.warn(`[plugins] ${id} failed to load: ${detail}`);
    }

    function setState(id: string, state: string, detail: string): void {
        const next = root.entries.map(e => e.id === id ? Object.assign({}, e, {
            state: state,
            detail: detail
        }) : e);
        root.entries = next;
    }

    function status(): var {
        return {
            discovered: root.discovered,
            pluginsDir: root.pluginsDir,
            count: root.entries.length,
            loaded: root.entries.filter(e => e.state === "loaded").length,
            failed: root.entries.filter(e => e.state === "failed").length,
            plugins: root.entries
        };
    }

    Process {
        id: listProcess

        command: ["horneroctl", "plugin", "list", "--json"]

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data;
            }
        }

        onExited: (exitCode, exitStatus) => {
            let parsed = [];
            try {
                const envelope = JSON.parse(root.buffer.trim());
                const raw = envelope && envelope.data ? envelope.data.plugins : null;
                const list = typeof raw === "string" ? JSON.parse(raw) : raw;
                if (Array.isArray(list))
                    parsed = list;
            } catch (e) {
                parsed = [];
            }
            root.entries = parsed.map(e => {
                const requestedEnabled = !!e.enabled && !!e.installed;
                const trusted = ["official", "trusted", "signed"].includes(e.trust);
                const enabled = requestedEnabled && trusted;
                return Object.assign({}, e, {
                    placement: typeof e.placement === "string" ? e.placement : "",
                    requestedEnabled: requestedEnabled,
                    enabled: enabled,
                    state: requestedEnabled && !trusted ? "blocked" : enabled ? "pending" : "disabled",
                    detail: requestedEnabled && !trusted
                        ? qsTr("This plugin is marked enabled, but its payload is not trusted. Review and trust it, then enable it again.")
                        : ""
                });
            });
            root.discovered = true;
        }
    }

    Component.onCompleted: reload()
}
