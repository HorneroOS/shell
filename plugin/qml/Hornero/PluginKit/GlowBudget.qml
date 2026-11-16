pragma Singleton

import QtQuick

// Internal: rations the luminous accent (visual language §9: at most
// three glowing items on a screen). Instruments ask for a lease when they
// want to glow; the first three holders get it, the rest render the
// same trace without glow. Leases are released on destruction.
QtObject {
    id: root

    readonly property int limit: 3
    property var _holders: []
    readonly property int held: root._holders.length

    function acquire(owner: var): bool {
        if (root._holders.indexOf(owner) >= 0)
            return true;
        if (root._holders.length >= root.limit)
            return false;
        root._holders = root._holders.concat([owner]);
        return true;
    }

    function release(owner: var): void {
        const i = root._holders.indexOf(owner);
        if (i < 0)
            return;
        const next = root._holders.slice();
        next.splice(i, 1);
        root._holders = next;
    }

    function holds(owner: var): bool {
        return root._holders.indexOf(owner) >= 0;
    }
}
