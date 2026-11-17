import QtQuick
import QtQuick.Controls
import "Placement.js" as Placement

// Host-owned anchored popover for PluginKit: a compact trigger (the
// `target` item, e.g. a bar indicator UiButton) opens a rich panel
// without the plugin creating its own top-level window. The host owns
// positioning (same placement rules as UiTooltip: all four bar edges,
// side flips when it would clip, always clamped inside the surface),
// focus (initial focus moves into the panel, Escape closes and
// returns focus to the trigger), dismissal (Escape or press outside)
// and monitor selection (the panel opens on the surface — hence the
// monitor — that already hosts the trigger).
//
// Escape cascade (docs/INTERACTION.md): the panel is inner transient
// content, so its Escape handler lives on the focused content and
// accepts the event. Content inside the panel with its own transient
// state still sees Escape first (key events start at the focused
// item); only an unhandled Escape closes the popover, and because it
// is accepted here it never reaches Drawers.dismissTopmost(), so one
// Escape press closes the popover before — never together with — the
// drawer or bar surface underneath it.
Popup {
    id: root

    required property Item target
    property string accessibleName: ""
    // "auto" | "below" | "above" | "left" | "right". "auto" opens away
    // from the owning bar (beside rail triggers, below/above horizontal
    // bars) and by free vertical half elsewhere; an explicit side flips
    // once only when it would clip.
    property string preferredSide: "auto"
    // Popout framing (visual language §7.1): 16 px sides.
    property int contentPadding: Theme.padding.large
    // Optional explicit first stop; by default the first focusable
    // descendant receives focus, falling back to the panel itself.
    property Item initialFocusItem: null
    // Side actually used by the last placement (read-only by convention).
    property string actualSide: ""

    default property alias content: container.data

    property bool _returnFocusToTarget: false

    // Native bar popouts (shell issue 449): when the trigger lives in a bar
    // host that offers the native popout panel, the popover never opens its
    // own window. Its content is handed to the shell's shared popout panel,
    // so it opens on hover, grows from the bar edge, moves between triggers
    // and closes exactly like native popouts. Elsewhere (dashboard, desktop)
    // it stays a regular anchored popover.
    property var hostPopout: null
    readonly property bool hosted: root.hostPopout !== null
    // True while the native popout shows this content (bar hosts only).
    readonly property bool hostOpen: root.hosted && root.hostPopout.hostPopoutOpen === true

    function _findHostPopout(): var {
        let p = root.target;
        while (p) {
            if ("hostRegisterPopout" in p)
                return p;
            p = p.parent;
        }
        return null;
    }

    function _attachHost(): void {
        const host = root._findHostPopout();
        if (!host || host === root.hostPopout)
            return;
        root.hostPopout = host;
        host.hostRegisterPopout(container);
    }

    Component.onCompleted: Qt.callLater(root._attachHost)
    onTargetChanged: Qt.callLater(root._attachHost)

    // Popovers live in surface (window-root) coordinates so a clipped
    // bar island never crops them; the surface picks the monitor.
    parent: {
        let p = target;
        while (p && p.parent)
            p = p.parent;
        return p ?? target;
    }

    modal: false
    dim: false
    focus: true
    // Escape is handled explicitly below so that it accepts the event
    // (cascade) and returns focus; Popup only adds press-outside.
    closePolicy: Popup.CloseOnPressOutside
    padding: 0
    margins: 0
    background: Item {}

    function toggle() {
        if (root.hosted) {
            root.hostPopout.hostTogglePopout();
            return;
        }
        if (opened)
            close();
        else
            open();
    }

    // Close from Keyboard: mark focus return, then close. Click-outside
    // and programmatic close() deliberately leave focus where the
    // user's press or the caller put it.
    function dismiss() {
        if (root.hosted) {
            root.hostPopout.hostClosePopout();
            return;
        }
        root._returnFocusToTarget = true;
        close();
    }

    // The bar (if any) that owns the trigger: the nearest ancestor that
    // publishes `surfaceOwner` (the shell's bars do). Its edge decides
    // the side, exactly like the shell's own popouts and tooltips.
    readonly property var _ownerBar: {
        let p = root.target ? root.target.parent : null;
        while (p) {
            if (p.surfaceOwner !== undefined)
                return p.surfaceOwner;
            p = p.parent;
        }
        return null;
    }

    // Placement through the shell's shared anchored-surface solver
    // (Placement.js, a verbatim copy of components/placement/Placement.js;
    // RFC 0001 §4): given the target rect and popover size in surface
    // coordinates, return the clamped position and the side used. Bar
    // triggers open away from their bar; elsewhere "auto" prefers the
    // free vertical half; an explicit side flips once when it clips.
    function placementFor(tx, ty, tw, th, tipW, tipH, availW, availH, gap, margin) {
        const auto = root.preferredSide === "auto";
        const owner = auto ? root._ownerBar : null;
        const side = auto ? (ty + th / 2 < availH / 2 ? "below" : "above") : root.preferredSide;
        const placed = Placement.solve({
            trigger: { x: tx, y: ty, width: tw, height: th },
            bar: owner ? Object.assign({}, owner, { floating: true, item: undefined }) : null,
            preferredSide: side,
            previousSide: root.actualSide,
            screen: { x: 0, y: 0, width: availW, height: availH, reserved: {} },
            size: { width: tipW, height: tipH },
            gutter: margin,
            gap: gap
        });
        return {
            "x": placed.x,
            "y": placed.y,
            "side": placed.side
        };
    }

    function updatePosition() {
        if (!target || !parent)
            return;
        Qt.callLater(() => {
            if (!target || !parent || !popoverRect)
                return;
            try {
                const pos = target.mapToItem(parent, 0, 0);
                const popW = popoverRect.width > 0 ? popoverRect.width : popoverRect.implicitWidth;
                const popH = popoverRect.height > 0 ? popoverRect.height : popoverRect.implicitHeight;
                const placed = placementFor(pos.x, pos.y, target.width, target.height, popW, popH, parent.width, parent.height, Theme.spacing.small, Theme.spacing.smaller);
                x = placed.x;
                y = placed.y;
                root.actualSide = placed.side;
            } catch (e) {
                // Target destroyed mid-layout — skip this pass.
            }
        });
    }

    function _firstFocusable(item) {
        if (!item || !item.children)
            return null;
        for (let i = 0; i < item.children.length; i++) {
            const child = item.children[i];
            try {
                if (child.visible && child.enabled !== false && child.activeFocusOnTab)
                    return child;
            } catch (e) {
            }
            const nested = _firstFocusable(child);
            if (nested)
                return nested;
        }
        return null;
    }

    function _focusInitial() {
        const wanted = root.initialFocusItem ?? _firstFocusable(container) ?? popoverRect;
        try {
            wanted.forceActiveFocus();
        } catch (e) {
            // Target item destroyed before the deferred focus ran.
        }
    }

    onOpened: {
        root._returnFocusToTarget = false;
        updatePosition();
        Qt.callLater(_focusInitial);
    }

    onClosed: {
        if (!root._returnFocusToTarget)
            return;
        root._returnFocusToTarget = false;
        try {
            if (root.target)
                root.target.forceActiveFocus();
        } catch (e) {
            // Trigger destroyed while open — nothing to return to.
        }
    }

    onPreferredSideChanged: {
        if (visible)
            updatePosition();
    }

    Connections {
        target: root.target

        function onXChanged() {
            if (root.visible)
                root.updatePosition();
        }
        function onYChanged() {
            if (root.visible)
                root.updatePosition();
        }
        function onWidthChanged() {
            if (root.visible)
                root.updatePosition();
        }
        function onHeightChanged() {
            if (root.visible)
                root.updatePosition();
        }
    }

    // Reposition on surface resize (including scale changes, which
    // resize the logical surface).
    Connections {
        target: root.parent

        function onWidthChanged() {
            if (root.visible)
                root.updatePosition();
        }
        function onHeightChanged() {
            if (root.visible)
                root.updatePosition();
        }
    }

    // Scan-in (RFC 0001 §3.6): the panel travels 6 px out of its anchor
    // edge and fades in with `enter`; it leaves with 4 px travel back
    // toward the anchor and `exit`/quick. Reduced motion keeps only the
    // ≤ 90 ms fade. Interactive from the first frame.
    readonly property real _travelSign: root.actualSide === "above" || root.actualSide === "left" ? 1 : -1
    readonly property bool _horizontalTravel: root.actualSide === "left" || root.actualSide === "right"
    property real _travel: 0

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.reducedMotion ? Theme.duration("fade") : Theme.duration("short")
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.anim.curves.enter
            }
            NumberAnimation {
                target: root
                property: "_travel"
                from: Theme.reducedMotion ? 0 : 6
                to: 0
                duration: Theme.duration("short")
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.anim.curves.enter
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: Theme.duration("fade")
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.anim.curves.exit
            }
            NumberAnimation {
                target: root
                property: "_travel"
                to: Theme.reducedMotion ? 0 : 4
                duration: Theme.duration("quick")
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.anim.curves.exit
            }
        }
    }

    // `panel` fill, 1 px `rule` border, radius 3, one restrained shadow,
    // and the notch: a 2 px `signal` line exactly as wide as the trigger
    // on the edge facing it, so the panel visibly originates from its
    // trigger even with animations off.
    contentItem: Rectangle {
        id: popoverRect

        implicitWidth: Math.max(320, container.implicitWidth + root.contentPadding * 2)
        implicitHeight: container.implicitHeight + root.contentPadding * 2

        color: Theme.palette.panel
        radius: Theme.rounding.small
        border.width: 1
        border.color: Theme.palette.rule
        antialiasing: true

        transform: Translate {
            x: root._horizontalTravel ? root._travelSign * root._travel : 0
            y: root._horizontalTravel ? 0 : root._travelSign * root._travel
        }

        // Fallback focus stop when the panel has no focusable content,
        // and the popover's Escape endpoint: inner transient state
        // accepts its own Escape first; only an unhandled Escape
        // reaches here, where it is accepted so the surface-level
        // cascade does not also fire.
        focus: true
        Keys.onEscapePressed: event => {
            event.accepted = true;
            root.dismiss();
        }

        Accessible.role: Accessible.Dialog
        Accessible.name: root.accessibleName

        Rectangle {
            id: notch

            readonly property point _trigger: {
                const _x = root.x + root.y + root.width + root.height;
                if (!root.target || !root.visible)
                    return Qt.point(0, 0);
                try {
                    return root.target.mapToItem(popoverRect, 0, 0);
                } catch (e) {
                    return Qt.point(0, 0);
                }
            }
            readonly property bool vertical: root.actualSide === "left" || root.actualSide === "right"

            visible: root.target !== null && root.actualSide.length > 0
            color: Theme.palette.signal
            x: vertical ? (root.actualSide === "right" ? 0 : parent.width - 2) : Math.max(0, Math.min(parent.width - width, _trigger.x))
            y: vertical ? Math.max(0, Math.min(parent.height - height, _trigger.y)) : (root.actualSide === "below" ? 0 : parent.height - 2)
            width: vertical ? 2 : Math.min(parent.width, root.target ? root.target.width : 0)
            height: vertical ? Math.min(parent.height, root.target ? root.target.height : 0) : 2
        }

        // Registration tick: the surface has keyboard focus.
        Rectangle {
            visible: root.opened && Theme.keyboardFocus
            x: 0
            y: 0
            width: 2
            height: 10
            color: Theme.palette.signal
        }

        Item {
            id: container

            // Hosted content is laid out by the native popout panel, which
            // already applies the native padding.
            anchors.fill: root.hosted ? undefined : parent
            anchors.margins: root.hosted ? 0 : root.contentPadding
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
