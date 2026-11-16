import QtQuick
import QtQuick.Controls
import "Placement.js" as Placement

// Host-owned accessible tooltip for PluginKit controls and plugin items.
// Mirrors the shell Tooltip placement (four bar edges, dashboard,
// popovers, desktop) without any shell internals: shows on hover AND
// keyboard focus after a consistent delay, Escape dismisses until the
// trigger is left and re-entered, and the tooltip stays clamped inside
// its surface. Content is plain text only — never put interactive
// elements or essential-only information in a tooltip.
Popup {
    id: root

    required property Item target
    property string text: ""
    property int delay: 500
    property int timeout: 0
    // "auto" | "below" | "above" | "left" | "right". "auto" opens away
    // from the owning bar (beside rail triggers, below/above horizontal
    // bars) and by free vertical half elsewhere; an explicit side flips
    // once only when it would clip.
    property string preferredSide: "auto"

    // A bar indicator with a native popout (shell issue 449) shows the
    // popout on hover, like native bar items, never a tooltip on top of it.
    readonly property var _hostPopout: {
        let p = root.target;
        while (p) {
            if ("hostRegisterPopout" in p)
                return p;
            p = p.parent;
        }
        return null;
    }
    readonly property bool _popoutOwned: root._hostPopout !== null && root._hostPopout.hostPopoutContent !== null
    readonly property bool _triggered: !root._popoutOwned && (hoverHandler.hovered || (target ? target.activeFocus : false))
    property bool _wanted: false
    property string _lastSide: ""
    property bool _dismissed: false

    // Tooltips live in surface (window-root) coordinates so a clipped
    // bar island or popover never crops them.
    parent: {
        let p = target;
        while (p && p.parent)
            p = p.parent;
        return p ?? target;
    }

    visible: root._wanted && !root._dismissed && root._triggered && root.text.length > 0
    modal: false
    focus: false
    closePolicy: Popup.NoAutoClose
    padding: 0
    margins: 0
    background: Item {}

    function dismiss() {
        root._dismissed = true;
    }

    function syncAccessibleDescription() {
        // Best effort for plain Items; PluginKit controls also bind
        // Accessible.description to their tooltipText directly.
        try {
            if (root.target)
                root.target.Accessible.description = root.text;
        } catch (e) {
        }
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
    // RFC 0001 §4): given the target rect and tooltip size in surface
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
            previousSide: root._lastSide,
            screen: { x: 0, y: 0, width: availW, height: availH, scale: 1, reserved: {} },
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
            if (!target || !parent || !tooltipRect)
                return;
            try {
                const pos = target.mapToItem(parent, 0, 0);
                const tipW = tooltipRect.width > 0 ? tooltipRect.width : tooltipRect.implicitWidth;
                const tipH = tooltipRect.height > 0 ? tooltipRect.height : tooltipRect.implicitHeight;
                const placed = placementFor(pos.x, pos.y, target.width, target.height, tipW, tipH, parent.width, parent.height, Theme.spacing.small, Theme.spacing.smaller);
                x = placed.x;
                y = placed.y;
                root._lastSide = placed.side;
            } catch (e) {
                // Target destroyed mid-layout — skip this pass.
            }
        });
    }

    onTextChanged: {
        syncAccessibleDescription();
        if (visible)
            updatePosition();
    }
    onVisibleChanged: {
        if (visible) {
            updatePosition();
            if (timeout > 0)
                hideTimer.restart();
        } else {
            hideTimer.stop();
        }
    }
    on_TriggeredChanged: {
        if (_triggered) {
            if (delay <= 0)
                _wanted = true;
            else
                showTimer.restart();
        } else {
            showTimer.stop();
            _wanted = false;
            _dismissed = false;
        }
    }

    Component.onCompleted: syncAccessibleDescription()

    HoverHandler {
        id: hoverHandler

        parent: root.target
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

    Timer {
        id: showTimer

        interval: root.delay
        onTriggered: root._wanted = true
    }

    Timer {
        id: hideTimer

        interval: root.timeout
        onTriggered: root.dismiss()
    }

    Shortcut {
        sequence: "Esc"
        enabled: root.visible
        context: Qt.WindowShortcut
        onActivated: root.dismiss()
    }

    // Tooltips fade with 4 px travel from the anchor, `enter` 90 ms;
    // exit `exit` 90 ms; no morph (visual language §11.2). Reduced motion
    // keeps only the ≤ 90 ms opacity fade.
    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.duration("fade")
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.anim.curves.enter
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: Theme.duration("fade")
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.anim.curves.exit
        }
    }

    // Tooltips are the highest elevation: `lifted` fill, 1 px
    // `ruleStrong` outline (3:1 on lifted), radius 3, Plex Sans 11.
    contentItem: Rectangle {
        id: tooltipRect

        implicitWidth: Math.min(tooltipText.implicitWidth, 360) + Theme.padding.normal * 2
        implicitHeight: tooltipText.implicitHeight + Theme.padding.small * 2 + 2

        color: Theme.palette.lifted
        radius: Theme.rounding.small
        border.width: 1
        border.color: Theme.palette.ruleStrong
        antialiasing: true

        Accessible.role: Accessible.ToolTip
        Accessible.name: root.text

        Text {
            id: tooltipText

            anchors.centerIn: parent
            width: Math.min(implicitWidth, 360)

            text: root.text
            color: Theme.palette.ink
            wrapMode: Text.WordWrap
            font.family: Theme.font.family.sans
            font.pointSize: Theme.font.size.small
        }
    }
}
