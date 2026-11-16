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
            if ("hostSurface" in p && "hostAvailableWidth" in p)
                return p;
            p = p.parent;
        }
        return null;
    }
    // In a bar an indicator reads like the native bar items: plain
    // onSurface label, no outline, a fully rounded hover layer.
    readonly property bool inBar: hostContext !== null && hostContext.hostSurface === "bar"
    // Native island style (shell issue 439): a bar section host advertises its
    // icon colour and sizes on the Loader; an indicator inside the status,
    // actions or clock island then matches its native neighbours exactly.
    readonly property var hostStyle: {
        let p = root.parent;
        while (p) {
            if ("hostIconSize" in p)
                return p;
            p = p.parent;
        }
        return null;
    }
    readonly property bool islandStyled: hostStyle !== null && hostStyle.hostIconSize > 0
    // Tray items and native status icons have no hover background: the
    // popout is the hover feedback. Indicators in those islands match; the
    // quick actions and clock islands keep the native button hover.
    readonly property bool quietHover: root.islandStyled && (root.hostStyle.hostSection === "status" || root.hostStyle.hostSection === "end")
    // A host may advertise sizes without a colour (transparent): then the
    // button keeps the native bar label colour instead of painting its
    // icon and text transparent (invisible inside the island).
    readonly property bool islandColoured: islandStyled && hostStyle.hostIconColor.a > 0
    // Rail styling is a bar concern only: a compact dashboard card also
    // reports hostCompact, and must keep full-size buttons.
    readonly property bool railCompact: inBar && hostContext.hostCompact === true && hostContext.hostAvailableWidth > 0
    readonly property int railWidth: railCompact ? hostContext.hostAvailableWidth : 0
    // Variants: "primary" (filled), "tonal" (quiet fill), "ghost" (text
    // button, no outline), "outlined" (explicit outline).
    readonly property color labelColor: root.variant === "primary" ? Theme.onPrimary : root.variant === "tonal" ? Theme.onSurface : root.islandColoured ? root.hostStyle.hostIconColor : root.inBar ? Theme.onSurface : Theme.primary

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

    // Optional Hornero Glyph name (native bar items are icon buttons).
    // Icon only: leave text empty; give the button an accessibleName.
    // (Named iconName: AbstractButton already has a FINAL `icon` group.)
    property string iconName: ""

    contentItem: Item {
        implicitWidth: layout.implicitWidth
        implicitHeight: layout.implicitHeight
        opacity: root.enabled ? 1 : 0.5

        Grid {
            id: layout

            anchors.centerIn: parent
            // Side by side normally; stacked on a narrow rail.
            columns: root.railCompact || root.text.length === 0 || root.iconName.length === 0 ? 1 : 2
            spacing: root.iconName.length > 0 && root.text.length > 0 ? Theme.spacingSmall / 2 : 0
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            UiIcon {
                visible: root.iconName.length > 0
                icon: root.iconName
                color: root.labelColor
                // Icon-only bar buttons use the native bar icon size.
                role: root.inBar && root.text.length === 0 ? "large" : "body"
                size: root.islandStyled ? root.hostStyle.hostIconSize : 0
            }

            Text {
                id: label

                visible: root.text.length > 0
                width: root.railCompact ? Math.min(implicitWidth, root.railWidth - root.leftPadding - root.rightPadding) : implicitWidth
                text: root.text
                color: root.labelColor
                font.family: Theme.fontFamily
                font.pointSize: root.islandStyled && root.hostStyle.hostTextSize > 0 ? root.hostStyle.hostTextSize : root.railCompact ? Theme.fontSizeSmall : Theme.fontSizeBody
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.NoWrap
                // Rail labels shrink to fit the rail rather than losing
                // characters; elision is only the last resort below the minimum.
                fontSizeMode: root.railCompact ? Text.Fit : Text.FixedSize
                minimumPointSize: 6
                elide: root.railCompact ? Text.ElideRight : Text.ElideNone
                maximumLineCount: root.railCompact ? 2 : 0
            }
        }
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
            color: root.variant === "primary" ? Theme.primary : root.variant === "tonal" ? Theme.surfaceContainerHighest : "transparent"
            // Bar items hover as a full pill like native bar buttons; with
            // no outline nothing clips the label ends.
            radius: root.inBar ? height / 2 : Theme.rounding
            border.width: root.variant === "outlined" ? 1 : 0
            border.color: Theme.outline
            opacity: root.enabled ? 1 : 0.5

            UiStateLayer {
                id: stateLayer

                anchors.fill: parent
                radius: surface.radius
                hovered: hover.hovered && !root.quietHover
                pressed: root.down
                disabled: !root.enabled
                color: root.labelColor
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
