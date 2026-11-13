import QtQuick
import QtQuick.Controls

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
    // "auto" picks right/left beside rail triggers and below/above by
    // vertical half; an explicit side is flipped only when it clips.
    property string preferredSide: "auto"
    property int contentPadding: Theme.spacing
    // Optional explicit first stop; by default the first focusable
    // descendant receives focus, falling back to the panel itself.
    property Item initialFocusItem: null
    // Side actually used by the last placement (read-only by convention).
    property string actualSide: ""

    default property alias content: container.data

    property bool _returnFocusToTarget: false

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
        if (opened)
            close();
        else
            open();
    }

    // Close from Keyboard: mark focus return, then close. Click-outside
    // and programmatic close() deliberately leave focus where the
    // user's press or the caller put it.
    function dismiss() {
        root._returnFocusToTarget = true;
        close();
    }

    // Pure placement: given the target rect and popover size in surface
    // coordinates, return the clamped position and the side used.
    // Same rules as UiTooltip.placementFor.
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
            if (!target || !parent || !popoverRect)
                return;
            try {
                const pos = target.mapToItem(parent, 0, 0);
                const popW = popoverRect.width > 0 ? popoverRect.width : popoverRect.implicitWidth;
                const popH = popoverRect.height > 0 ? popoverRect.height : popoverRect.implicitHeight;
                const placed = placementFor(pos.x, pos.y, target.width, target.height, popW, popH, parent.width, parent.height, Theme.spacingSmall, Theme.spacingSmall);
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

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: 120
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: 120
        }
    }

    contentItem: Rectangle {
        id: popoverRect

        implicitWidth: container.implicitWidth + root.contentPadding * 2
        implicitHeight: container.implicitHeight + root.contentPadding * 2

        color: Theme.surfaceContainer
        radius: Theme.rounding
        border.width: 1
        border.color: Theme.outlineVariant
        antialiasing: true

        // Fallback focus stop when the panel has no focusable content,
        // and the popover's Escape endpoint: the handler sits above
        // the content in the focus chain, so inner transient state
        // accepts its own Escape first (cascade tier 1) and only an
        // unhandled Escape reaches here, where it is accepted so the
        // surface-level cascade does not also fire.
        focus: true
        Keys.onEscapePressed: event => {
            event.accepted = true;
            root.dismiss();
        }

        Accessible.role: Accessible.Dialog
        Accessible.name: root.accessibleName

        Item {
            id: container

            anchors.fill: parent
            anchors.margins: root.contentPadding
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
