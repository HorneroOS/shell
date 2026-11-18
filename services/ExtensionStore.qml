pragma Singleton

import "extensionstore.js" as Store
import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

// Extension store (competitive gap #4): the official catalogue and the
// lifecycle verbs Control Center › Extensions runs. horneroctl stays the
// single writer of plugin state; this service only runs its documented
// JSON verbs (hornero docs/PLUGIN_LIFECYCLE_JSON.md) asynchronously, one
// at a time, and keeps what the pane needs to show: the running verb with
// elapsed seconds, and the last result or error per extension id.
//
// Consent lives in the pane (a two-step guard per verb, the Control
// Center apply policy for commands without an inverse); run() is only
// called from the confirming click. Nothing here loads plugin code.
Singleton {
    id: root

    property var catalogue: []
    property string catalogueRevision: ""
    property string catalogueError: ""
    property string catalogueErrorCode: ""
    property bool catalogueLoaded: false
    readonly property bool catalogueLoading: catalogueProc.running

    // Running verb: {verb, id, name, startedAtMs} or null.
    property var job: null
    property int jobSeconds: 0
    readonly property bool busy: job !== null
    // Last outcome per id: {verb, ok, message, code, guidance, atMs}.
    property var outcomes: ({})

    signal finished(string verb, string pluginId, bool ok)

    // Language of the store's own lines (consent, guidance, progress) and
    // of the catalogue's bilingual permission text: the shell UI language
    // unless plugins.storeLanguage forces one.
    readonly property bool spanish: Config.plugins.storeLanguage === "es" || (Config.plugins.storeLanguage === "auto" && Language.active.toLowerCase().startsWith("es"))

    function isSpanish(): bool {
        return root.spanish;
    }

    function entry(pluginId: string): var {
        return root.catalogue.find(e => e.id === pluginId) ?? null;
    }

    function outcome(pluginId: string): var {
        return root.outcomes[pluginId] ?? null;
    }

    function clearOutcome(pluginId: string): void {
        if (!(pluginId in root.outcomes))
            return;
        const next = Object.assign({}, root.outcomes);
        delete next[pluginId];
        root.outcomes = next;
    }

    function refreshCatalogue(): void {
        if (catalogueProc.running)
            return;
        root.catalogueError = "";
        root.catalogueErrorCode = "";
        catalogueProc.running = true;
    }

    // Run one guarded verb. Returns false (and runs nothing) while another
    // verb is in flight or when the verb/id is not one horneroctl accepts.
    function run(verb: string, pluginId: string, name: string): bool {
        if (root.busy)
            return false;
        const needsRevision = verb === "install" || verb === "update";
        if (needsRevision && root.catalogueRevision.length === 0)
            return false;
        const argv = Store.commandFor(verb, pluginId, needsRevision ? root.catalogueRevision : "");
        if (argv.length === 0)
            return false;
        root.clearOutcome(pluginId);
        root.job = {
            verb: verb,
            id: pluginId,
            name: name || pluginId,
            startedAtMs: Date.now()
        };
        root.jobSeconds = 0;
        jobProc.command = argv;
        jobProc.running = true;
        return true;
    }

    function progressText(): string {
        return root.job ? Store.progressText(root.job.verb, root.job.name, root.jobSeconds, root.isSpanish()) : "";
    }

    function _record(verb: string, pluginId: string, env: var): void {
        const next = Object.assign({}, root.outcomes);
        next[pluginId] = {
            verb: verb,
            ok: env.ok,
            message: env.message,
            code: env.code,
            guidance: env.ok ? "" : Store.guidance(env.code, root.isSpanish()),
            data: env.data,
            atMs: Date.now()
        };
        root.outcomes = next;
    }

    Process {
        id: catalogueProc

        command: ["horneroctl", "--json", "plugin", "catalog"]
        stdout: StdioCollector {
            id: catalogueOut
        }
        onExited: (exitCode, exitStatus) => {
            const env = Store.parseEnvelope(catalogueOut.text, exitCode);
            if (env.ok) {
                try {
                    root.catalogue = JSON.parse(env.data.plugins || "[]");
                } catch (e) {
                    root.catalogue = [];
                }
                root.catalogueRevision = String(env.data.revision || "");
                root.catalogueLoaded = true;
            } else {
                root.catalogueRevision = "";
                root.catalogueErrorCode = env.code;
                root.catalogueError = env.message || qsTr("Catalogue unavailable (network or horneroctl).");
            }
        }
    }

    Process {
        id: jobProc

        stdout: StdioCollector {
            id: jobOut
        }
        onExited: (exitCode, exitStatus) => {
            const job = root.job;
            const env = Store.parseEnvelope(jobOut.text, exitCode);
            root.job = null;
            if (!job)
                return;
            root._record(job.verb, job.id, env);
            // Re-read state from its owners: the shell's plugin host and
            // the catalogue (which reports installed/update state).
            Plugins.reload();
            if (["install", "update", "rollback", "remove"].includes(job.verb))
                root.refreshCatalogue();
            root.finished(job.verb, job.id, env.ok);
        }
    }

    Timer {
        running: root.busy
        repeat: true
        interval: 1000
        onTriggered: root.jobSeconds = root.job ? Math.floor((Date.now() - root.job.startedAtMs) / 1000) : 0
    }
}
