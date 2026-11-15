import QtQuick
import QtQuick.Controls

Button {
    id: root

    property string variant: "primary"
    property string tooltipText: ""
    property string accessibleName: root.text

    // Narrow-rail fit (bar indicators in a vertical or thin bar): the
    // host injects hostCompact/hostAvailableWidth into the entrypoint
    // root that owns this button. Walk up to that root instead of
    // requiring every plugin to forward the values, so one primitive
    // fixes every bar indicator. Outside a narrow rail nothing changes.
    readonly property var hostContext: {
        let p = root.parent;
        while (p) {
            if ("hostAvailableWidth" in p)
                return p;
            p = p.parent;
        }
        return null;
    }
    readonly property bool railCompact: hostContext !== null && hostContext.hostCompact === true && hostContext.hostAvailableWidth > 0
    readonly property int railWidth: railCompact ? hostContext.hostAvailableWidth : 0

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.Button
    Accessible.description: root.tooltipText

    // Keyboard contract (shell issue 376): one deterministic tab stop while
    // enabled (declaration order is tab order), Space is native to
    // Button, Enter/Return are added here so both activate.
    activeFocusOnTab: enabled
    Keys.onReturnPressed: event => {
        if (enabled) {
            root.click();
            event.accepted = true;
        }
    }
    Keys.onEnterPressed: event => {
        if (enabled) {
            root.click();
            event.accepted = true;
        }
    }

    UiTooltip {
        target: root
        text: root.tooltipText
    }

    // Outside a narrow rail the Controls style padding is kept as is.
    leftPadding: root.railCompact ? 2 : root.implicitLeftPadding
    rightPadding: root.railCompact ? 2 : root.implicitRightPadding
    topPadding: root.railCompact ? 2 : root.implicitTopPadding
    bottomPadding: root.railCompact ? 2 : root.implicitBottomPadding

    // On a narrow rail the label must fit the rail: the button never
    // grows past it, and long text elides instead of spilling out of
    // the host Loader (which clips at the rail edge).
    implicitWidth: root.railCompact ? Math.min(root.railWidth, contentItem.implicitWidth + root.leftPadding + root.rightPadding) : contentItem.implicitWidth + root.leftPadding + root.rightPadding

    contentItem: Text {
        text: root.text
        color: root.variant === "ghost" ? Theme.primary : Theme.onPrimary
        font.family: Theme.fontFamily
        font.pixelSize: root.railCompact ? Theme.fontSizeSmall : Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.NoWrap
        // Rail labels shrink to fit the rail rather than losing
        // characters; elision is only the last resort below the minimum.
        fontSizeMode: root.railCompact ? Text.Fit : Text.FixedSize
        minimumPixelSize: 8
        elide: root.railCompact ? Text.ElideRight : Text.ElideNone
        maximumLineCount: root.railCompact ? 2 : 0
        opacity: root.enabled ? 1 : 0.5
    }

    // Native interaction: hover and press show the shell state layer
    // (8% / 12%, ripple from the contact point); the focus ring appears
    // only for keyboard focus and floats 2 px outside the shape.
    HoverHandler {
        id: hover

        enabled: root.enabled
    }

    TapHandler {
        id: tap

        enabled: root.enabled
        onPressedChanged: {
            if (pressed && stateLayer)
                stateLayer.startRipple(point.position.x, point.position.y);
        }
    }

    background: Item {
        implicitWidth: 40
        implicitHeight: 24

        Rectangle {
            id: surface

            anchors.fill: parent
            color: root.variant === "ghost" ? "transparent" : Theme.primary
            // A capsule (full rounding) clips the ends of a label on a
            // narrow rail; a small radius keeps the whole label inside.
            radius: root.railCompact ? Theme.roundingSmall : Theme.rounding
            border.width: root.variant === "ghost" ? 1 : 0
            border.color: Theme.outline
            opacity: root.enabled ? 1 : 0.5

            UiStateLayer {
                id: stateLayer

                anchors.fill: parent
                radius: surface.radius
                hovered: hover.hovered
                pressed: root.down
                disabled: !root.enabled
                color: root.variant === "ghost" ? Theme.primary : Theme.onPrimary
            }
        }

        // Keyboard-only focus ring (shell FocusRing contract).
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: surface.radius + 2
            color: "transparent"
            border.width: 2
            border.color: Theme.focusRing
            visible: root.activeFocus && Theme.keyboardFocus && root.enabled
        }
    }
}
