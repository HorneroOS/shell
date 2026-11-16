import QtQuick
import QtQuick.Controls

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
    // "auto" picks right/left beside rail triggers and below/above by
    // vertical half; an explicit side is flipped only when it clips.
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

    // Pure placement: given the target rect and tooltip size in surface
    // coordinates, return the clamped position and the side used.
    function placementFor(tx, ty, tw, th, tipW, tipH, availW, availH, gap, margin) {
        const centerX = tx + tw / 2;
        const centerY = ty + th / 2;
        let side = root.preferredSide;
        if (side === "auto") {
            if (centerX < availW * 0.18 && tx + tw + gap + tipW + margin <= availW)
                side = "right";
            else if (centerX > availW * 0.82 && tx - gap - tipW >= margin)
                side = "left";
            else
                side = centerY < availH / 2 ? "below" : "above";
        }
        if (side === "below" && ty + th + gap + tipH > availH - margin && ty - gap - tipH >= margin)
            side = "above";
        else if (side === "above" && ty - gap - tipH < margin && ty + th + gap + tipH <= availH - margin)
            side = "below";
        else if (side === "right" && tx + tw + gap + tipW > availW - margin && tx - gap - tipW >= margin)
            side = "left";
        else if (side === "left" && tx - gap - tipW < margin && tx + tw + gap + tipW <= availW - margin)
            side = "right";

        let newX = centerX - tipW / 2;
        let newY = centerY - tipH / 2;
        if (side === "below")
            newY = ty + th + gap;
        else if (side === "above")
            newY = ty - tipH - gap;
        else if (side === "right")
            newX = tx + tw + gap;
        else if (side === "left")
            newX = tx - tipW - gap;

        const maxX = Math.max(margin, availW - tipW - margin);
        const maxY = Math.max(margin, availH - tipH - margin);
        return {
            "x": Math.max(margin, Math.min(newX, maxX)),
            "y": Math.max(margin, Math.min(newY, maxY)),
            "side": side
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
