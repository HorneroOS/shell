import QtQuick

// Live rect of `item` in `root` coordinates (RFC 0001 §4 rule 3).
//
// mapToItem() alone is not reactive: a binding over it only re-runs when
// `item` itself changes, so a trigger that moves because an ancestor
// moved (bar reorder, island resize, bar slide-in, monitor change) would
// leave a stale anchor. The binding below reads the geometry of every
// ancestor of both items, which registers them as dependencies, so the
// rect is re-evaluated exactly when something on either chain moves or
// resizes — no polling, no per-frame cost while nothing moves.
QtObject {
    id: tracker

    property Item item: null
    property Item root: null

    readonly property rect rect: {
        const it = tracker.item;
        const r = tracker.root;
        if (!it || !r)
            return Qt.rect(0, 0, 0, 0);
        let guard = 0;
        for (let p = it; p && guard < 64; p = p.parent, guard++) {
            void p.x;
            void p.y;
            void p.width;
            void p.height;
            void p.visible;
        }
        guard = 0;
        for (let p = r; p && guard < 64; p = p.parent, guard++) {
            void p.x;
            void p.y;
        }
        try {
            const pt = it.mapToItem(r, 0, 0);
            return Qt.rect(pt.x, pt.y, it.width, it.height);
        } catch (e) {
            // The item was destroyed between the change and this pass.
            return Qt.rect(0, 0, 0, 0);
        }
    }
    readonly property bool valid: item !== null && root !== null && (rect.width > 0 || rect.height > 0)
}
