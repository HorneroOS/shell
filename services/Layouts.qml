pragma Singleton

import qs.config
import QtQuick
import Quickshell
import "layouts.js" as Model

// "My tweaks for a layout" (Control Center > Layout). `remember` stores the
// current bar sizes, type face and scales as the override row of a layout
// (Config.layouts.overrides); after a preset apply, `reapplyAfterPreset`
// lays that row back on top once horneroctl has rewritten shell.json.
// Applying through the CLI directly bypasses the shell, so the row is not
// re-applied there; "Apply my tweaks" does it by hand.
Singleton {
    id: root

    // horneroctl rewrites shell.json and the shell reloads it; wait for that
    // before writing, or the reload would overwrite the tweaks.
    readonly property int settleMs: 900

    property string pendingId: ""

    function _node(path: string): var {
        const parts = path.split(".");
        let node = Config;
        for (let i = 0; i < parts.length - 1; i++) {
            node = node?.[parts[i]];
            if (node === undefined || node === null)
                return null;
        }
        return node;
    }

    function _get(path: string): var {
        const node = root._node(path);
        return node ? node[path.split(".").pop()] : undefined;
    }

    function _set(path: string, value: var): void {
        const node = root._node(path);
        if (node)
            node[path.split(".").pop()] = value;
    }

    function rowFor(id: string): var {
        return Model.rowFor(Config.layouts.overrides, id);
    }

    function count(id: string): int {
        return Object.keys(root.rowFor(id)).length;
    }

    function remember(id: string): void {
        Config.layouts.overrides = Model.remember(Config.layouts.overrides, id, root._get);
        Config.save();
    }

    function forget(id: string): void {
        Config.layouts.overrides = Model.forget(Config.layouts.overrides, id);
        Config.save();
    }

    function applyNow(id: string): void {
        if (Model.applyRow(Config.layouts.overrides, id, root._set).length > 0)
            Config.save();
    }

    // Call after `horneroctl shell preset apply <id>` exited successfully.
    function reapplyAfterPreset(id: string): void {
        if (root.count(id) === 0)
            return;
        root.pendingId = id;
        settle.restart();
    }

    Timer {
        id: settle

        interval: root.settleMs
        onTriggered: {
            const id = root.pendingId;
            root.pendingId = "";
            root.applyNow(id);
        }
    }
}
