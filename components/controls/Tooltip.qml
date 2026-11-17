import ".."
import qs.components.placement
import qs.components.motion
import qs.services
import qs.config
import QtQuick

// Hover tooltip on the shared anchored-surface contract (RFC 0001 §4):
// placed by the same solver as popouts, so it opens away from the owning
// bar (down from top bars, up from bottom bars, inward from rails),
// flips once when the preferred side cannot fit and stays clamped to the
// screen. Elsewhere it prefers the free vertical half. It lives in the
// window's root item so clipped bar islands never crop it, tracks its
// trigger live, and fades with 4 px travel from the anchor (enter 90 ms,
// exit 90 ms; visual language §11.2). Never takes focus or input.
AnchoredSurface {
    id: root

    required property Item target
    required property string text
    property int delay: 500
    property int timeout: 0

    property bool tooltipVisible: false

    // The bar (if any) that owns the trigger: nearest ancestor that
    // publishes `surfaceOwner` (modules/bar/Bar.qml).
    readonly property var _ownerBar: {
        let p = target?.parent ?? null;
        while (p) {
            if (p.surfaceOwner !== undefined)
                return p;
            p = p.parent;
        }
        return null;
    }

    parent: target?.Window.contentItem ?? target
    z: 100000

    anchorItem: target
    // Tooltips never attach to a bar: they keep the 4 px gap.
    owner: _ownerBar ? Object.assign({}, _ownerBar.surfaceOwner, {
        floating: true
    }) : null
    ownerItem: _ownerBar
    preferredSide: {
        if (!target || !parent)
            return "below";
        const r = anchorRect;
        return r.y + r.height / 2 < parent.height / 2 ? "below" : "above";
    }
    preferredWidth: label.implicitWidth + Appearance.padding.normal * 2
    preferredHeight: label.implicitHeight + Appearance.padding.smaller * 2
    open: tooltipVisible && text.length > 0 && (target?.visible ?? false)
    intent: "hover"
    key: text
    morphs: false
    travelDuration: Choreography.quick
    notch: false
    elevation: 4
    fill: Signal.palette.lifted
    gap: Appearance.spacing.small
    enabled: false

    // Alert-coloured text on this `lifted` fill must use this pairing: some
    // palettes (Dusk) put plain `alert` under 4.5:1 here.
    readonly property color alertColor: Atmosphere.alertText

    Accessible.role: Accessible.ToolTip
    Accessible.name: text

    Timer {
        id: showTimer

        interval: root.delay
        onTriggered: root.tooltipVisible = true
    }

    Timer {
        id: hideTimer

        interval: root.timeout
        onTriggered: root.tooltipVisible = false
    }

    // Hover of the trigger itself, whatever kind of item it is (buttons,
    // sliders, switches): a passive handler never steals the press.
    HoverHandler {
        id: hover

        parent: root.target
        onHoveredChanged: {
            if (hovered) {
                showTimer.restart();
                if (root.timeout > 0)
                    hideTimer.restart();
            } else {
                showTimer.stop();
                hideTimer.stop();
                root.tooltipVisible = false;
            }
        }
    }

    StyledText {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: Signal.palette.ink
        font.pointSize: Appearance.font.size.small
    }
}
