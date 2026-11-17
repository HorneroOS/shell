import QtQuick

// Structurally stable host model.
//
// The Plugins service republishes `entries` on every load-state change, and
// every host derives a fresh array of fresh objects from it. A Repeater
// treats that as a full model reset, so each plugin that reported loaded or
// failed destroyed and re-created every other plugin's delegate: a slow
// entrypoint was cancelled mid-incubation ("Object or context destroyed
// during incubation") again and again and stayed `pending`.
//
// StableList republishes `list` only when the structure a delegate is built
// from changes (id, entrypoint, placement hints, order, ...). Volatile
// bookkeeping (load state, timings, diagnostics, manifest metadata read
// after the first load) never rebuilds delegates; delegates that display it
// read the live entry through Plugins.entryFor(id). A reload bumps
// `attempts`, which is part of the structure, so reload still re-creates
// the Loaders.
QtObject {
    id: root

    // Live host copies, e.g. Plugins.dashboardPlugins() (or sections of them).
    property var source: []
    // Stable array to hand to a Repeater.
    property var list: []
    property string signature: ""

    // Dropped at any depth before comparing (dashboard sections nest plugin
    // copies). attemptTimesMs is bookkeeping; `attempts`, the reload
    // counter, stays in the signature.
    readonly property var volatileKeys: ["state", "detail", "loadMs", "loadStartedAtMs", "lastStateAtMs", "attemptTimesMs", "diagnostics", "marketplace", "description", "translations", "hostLoadStartedAtMs", "failedSurfaces"]

    function structure(items: var): string {
        // `volatile` is a reserved word for older qmllint, so call it ignored.
        const ignored = root.volatileKeys;
        return JSON.stringify(items ?? [], (key, value) => ignored.includes(key) ? undefined : value);
    }

    function sync(): void {
        const next = root.structure(root.source);
        if (next === root.signature)
            return;
        root.signature = next;
        root.list = root.source ?? [];
    }

    onSourceChanged: root.sync()
    Component.onCompleted: root.sync()
}
