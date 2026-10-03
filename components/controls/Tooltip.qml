import ".."
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Popup {
    id: root

    required property Item target
    required property string text
    property int delay: 500
    property int timeout: 0

    property bool tooltipVisible: false
    property Timer showTimer: Timer {
        interval: root.delay
        onTriggered: root.tooltipVisible = true
    }
    property Timer hideTimer: Timer {
        interval: root.timeout
        onTriggered: root.tooltipVisible = false
    }

    // Popup properties - doesn't affect layout
    parent: {
        // Bar triggers sit inside clipped islands, so their nearest
        // anchors.fill ancestor is often only the 48 px bar itself. Keep
        // the tooltip in the owning layer-surface coordinate space instead
        // of clipping it to that island.
        const windowContent = QsWindow.window?.contentItem;
        if (windowContent)
            return windowContent;

        let p = target;
        // Walk up to find the root Item (usually has anchors.fill: parent)
        while (p && p.parent) {
            const parentItem = p.parent;
            // Check if this looks like a root pane Item
            if (parentItem && parentItem.anchors && parentItem.anchors.fill !== undefined) {
                return parentItem;
            }
            p = parentItem;
        }
        // Fallback
        return target.parent?.parent?.parent ?? target.parent?.parent ?? target.parent ?? target;
    }

    visible: tooltipVisible
    modal: false
    closePolicy: Popup.NoAutoClose
    padding: 0
    margins: 0
    background: Item {}

    // Update position when target moves or tooltip becomes visible
    onTooltipVisibleChanged: {
        if (tooltipVisible) {
            Qt.callLater(updatePosition);
        }
    }
    Connections {
        target: root.target
        function onXChanged() {
            if (root.tooltipVisible)
                root.updatePosition();
        }
        function onYChanged() {
            if (root.tooltipVisible)
                root.updatePosition();
        }
        function onWidthChanged() {
            if (root.tooltipVisible)
                root.updatePosition();
        }
        function onHeightChanged() {
            if (root.tooltipVisible)
                root.updatePosition();
        }
    }

    function updatePosition() {
        if (!target || !parent)
            return;

        // Wait for tooltipRect to have its size calculated
        Qt.callLater(() => {
            if (!target || !parent || !tooltipRect)
                return;

            // The target can be destroyed between the hover event and this
            // call (layout switches, entry reloads) — bail out instead of
            // throwing a TypeError from mapToItem.
            try {
                // Get target position in parent's coordinate system
                const targetPos = target.mapToItem(parent, 0, 0);
                const targetCenterX = targetPos.x + target.width / 2;

            // Get tooltip size (use width/height if available, otherwise implicit)
            const tooltipWidth = tooltipRect.width > 0 ? tooltipRect.width : tooltipRect.implicitWidth;
            const tooltipHeight = tooltipRect.height > 0 ? tooltipRect.height : tooltipRect.implicitHeight;

            const padding = Appearance.padding.normal;
            const gap = Appearance.spacing.small;
            const targetCenterY = targetPos.y + target.height / 2;
            const onLeftEdge = targetCenterX < parent.width * 0.18;
            const onRightEdge = targetCenterX > parent.width * 0.82;
            let newX = targetCenterX - tooltipWidth / 2;
            let newY = targetPos.y - tooltipHeight - gap;

            // Rails read best with the tooltip beside the trigger. If there
            // is not room, fall back to the vertical placement used by bars.
            if (onLeftEdge && parent.width - targetPos.x - target.width >= tooltipWidth + gap + padding) {
                newX = targetPos.x + target.width + gap;
                newY = targetCenterY - tooltipHeight / 2;
            } else if (onRightEdge && targetPos.x >= tooltipWidth + gap + padding) {
                newX = targetPos.x - tooltipWidth - gap;
                newY = targetCenterY - tooltipHeight / 2;
            } else if (targetCenterY < parent.height / 2) {
                newY = targetPos.y + target.height + gap;
            }

            // Flip if the preferred side is clipped, then clamp to the
            // surface. This keeps top, bottom, left and right bars usable.
            const maxX = Math.max(padding, parent.width - tooltipWidth - padding);
            const maxY = Math.max(padding, parent.height - tooltipHeight - padding);
            if (newY + tooltipHeight > parent.height - padding)
                newY = targetPos.y - tooltipHeight - gap;
            x = Math.max(padding, Math.min(newX, maxX));
            y = Math.max(padding, Math.min(newY, maxY));
            } catch (e) {
                // Target destroyed mid-layout — skip this positioning pass
            }
        });
    }

    enter: Transition {
        Anim {
            property: "opacity"
            from: 0
            to: 1
            duration: Appearance.anim.durations.expressiveFastSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
        }
    }

    exit: Transition {
        Anim {
            property: "opacity"
            from: 1
            to: 0
            duration: Appearance.anim.durations.expressiveFastSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveFastSpatial
        }
    }

    // Monitor hover state
    Connections {
        target: root.target
        function onHoveredChanged() {
            if (target.hovered) {
                showTimer.start();
                if (timeout > 0) {
                    hideTimer.stop();
                    hideTimer.start();
                }
            } else {
                showTimer.stop();
                hideTimer.stop();
                tooltipVisible = false;
            }
        }
    }

    contentItem: StyledRect {
        id: tooltipRect

        implicitWidth: tooltipText.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: tooltipText.implicitHeight + Appearance.padding.smaller * 2

        color: Colours.palette.m3surfaceContainerHighest
        radius: Appearance.rounding.small
        antialiasing: true

        // Add elevation for depth
        Elevation {
            anchors.fill: parent
            radius: parent.radius
            z: -1
            level: 3
        }

        StyledText {
            id: tooltipText

            anchors.centerIn: parent

            text: root.text
            color: Colours.palette.m3onSurface
            font.pointSize: Appearance.font.size.small
        }
    }

    Component.onCompleted: {
        if (tooltipVisible) {
            updatePosition();
        }
    }
}
