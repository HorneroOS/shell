import QtQuick
import QtQuick.Controls

// Signal button (visual language §8). Rectangles with small radii, no
// ripple, no scale: state is a fill change.
//
//   variant: "secondary" (default) panel fill, 1 px ruleStrong outline
//            "primary"   signal fill, onSignal label — one per surface
//            "quiet"     no fill or outline until hovered (toolbars,
//                        bar indicators)
//            "danger"    alertWell fill, onAlertWell label
//   glyph:   optional Hornero Glyph name (icon-only: leave text empty
//            and set accessibleName)
//   open:    true while the surface this button opens is showing —
//            raised fill plus the 2 px signal underline toward it
//
// Rest → hover `raised` → pressed `lifted`; focus is a 2 px `focus` ring
// 2 px outside (inside in bars so it never clips), keyboard only.
Button {
    id: root

    property string variant: "secondary"
    property string glyph: ""
    property bool open: false
    property string tooltipText: ""
    property string accessibleName: root.text

    // Narrow-rail fit: the bar host injects hostSurface/hostCompact/
    // hostAvailableWidth into the entrypoint root that owns this button.
    readonly property var hostContext: {
        let p = root.parent;
        while (p) {
            if ("hostSurface" in p && "hostAvailableWidth" in p)
                return p;
            p = p.parent;
        }
        return null;
    }
    readonly property bool inBar: hostContext !== null && hostContext.hostSurface === "bar"
    // Bar section hosts advertise their glyph colour and sizes so an
    // indicator inside a native island matches its neighbours exactly.
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
    readonly property bool islandColoured: islandStyled && hostStyle.hostIconColor.a > 0
    readonly property bool islandTextColoured: islandStyled && hostStyle.hostTextColor && hostStyle.hostTextColor.a > 0
    // Tray items and native status glyphs have no hover fill: the popout
    // is the hover feedback. Indicators in those islands match.
    readonly property bool quietHover: root.islandStyled && (root.hostStyle.hostSection === "status" || root.hostStyle.hostSection === "end")
    readonly property bool railCompact: inBar && hostContext.hostCompact === true && hostContext.hostAvailableWidth > 0
    readonly property int railWidth: railCompact ? hostContext.hostAvailableWidth : 0
    // In a bar every indicator is a quiet segment, whatever its variant.
    readonly property string effectiveVariant: root.inBar ? "quiet" : root.variant

    readonly property color labelColor: !root.enabled ? Theme.palette.inkFaint : root.effectiveVariant === "primary" ? Theme.palette.onSignal : root.effectiveVariant === "danger" ? Theme.palette.onAlertWell : (root.text.length > 0 && root.glyph.length === 0 && root.islandTextColoured) ? root.hostStyle.hostTextColor : root.islandColoured ? root.hostStyle.hostIconColor : (root.islandTextColoured ? root.hostStyle.hostTextColor : Theme.palette.ink)
    readonly property color fillColor: {
        const v = root.effectiveVariant;
        if (v === "primary")
            return Theme.palette.signal;
        if (v === "danger")
            return Theme.palette.alertWell;
        if (root.down)
            return Theme.palette.lifted;
        if ((root.hovered && !root.quietHover) || root.open)
            return Theme.palette.raised;
        return v === "secondary" ? Theme.palette.panel : "transparent";
    }

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.Button
    Accessible.description: root.tooltipText

    // Keyboard contract: one tab stop while enabled; Space is native to
    // Button, Enter/Return are added so both activate.
    activeFocusOnTab: enabled
    hoverEnabled: enabled
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

    leftPadding: root.railCompact ? 2 : root.text.length > 0 ? Theme.padding.larger : Theme.padding.normal
    rightPadding: root.leftPadding
    topPadding: root.railCompact ? 2 : Theme.padding.small
    bottomPadding: root.topPadding
    implicitWidth: root.railCompact ? Math.min(root.railWidth, contentItem.implicitWidth + root.leftPadding + root.rightPadding) : Math.max(implicitBackgroundWidth, contentItem.implicitWidth + root.leftPadding + root.rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight, contentItem.implicitHeight + root.topPadding + root.bottomPadding)

    contentItem: Item {
        implicitWidth: layout.implicitWidth
        implicitHeight: layout.implicitHeight

        Grid {
            id: layout

            anchors.centerIn: parent
            columns: root.railCompact || root.text.length === 0 || root.glyph.length === 0 ? 1 : 2
            spacing: root.glyph.length > 0 && root.text.length > 0 ? Theme.spacing.smaller : 0
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            UiIcon {
                visible: root.glyph.length > 0
                name: root.glyph
                color: root.labelColor
                size: root.islandStyled ? root.hostStyle.hostIconSize : root.inBar && root.text.length === 0 ? Theme.font.size.large : Theme.font.size.larger
            }

            Text {
                // A narrow rail has no room for a label next to its glyph:
                // the glyph stays (tooltip and accessible name carry the
                // text) instead of an elided "Sun Ca..."
                visible: root.text.length > 0 && !(root.railCompact && root.glyph.length > 0)
                width: root.railCompact ? Math.min(implicitWidth, root.railWidth - root.leftPadding - root.rightPadding) : implicitWidth
                text: root.text
                color: root.labelColor
                font.family: root.islandStyled && root.hostStyle.hostTextFamily && root.hostStyle.hostTextFamily.length > 0 ? root.hostStyle.hostTextFamily : Theme.font.family.sans
                font.weight: root.effectiveVariant === "primary" ? Font.Medium : (root.islandStyled && root.hostStyle.hostTextWeight > 0 ? root.hostStyle.hostTextWeight : Font.Normal)
                font.pointSize: root.islandStyled && root.hostStyle.hostTextSize > 0 ? root.hostStyle.hostTextSize : root.railCompact ? Theme.font.size.small : Theme.font.size.smaller
                font.features: ({
                        "tnum": 1
                    })
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.NoWrap
                fontSizeMode: root.railCompact ? Text.Fit : Text.FixedSize
                minimumPointSize: 6
                elide: root.railCompact ? Text.ElideRight : Text.ElideNone
                maximumLineCount: root.railCompact ? 2 : 0
            }
        }
    }

    background: Item {
        implicitWidth: 28
        implicitHeight: root.inBar && root.hostContext.hostAvailableHeight > 0 ? Math.min(28, root.hostContext.hostAvailableHeight) : 28

        Rectangle {
            id: surface

            anchors.fill: parent
            radius: Theme.rounding.small
            color: root.fillColor
            border.width: root.effectiveVariant === "secondary" || root.effectiveVariant === "danger" ? 1 : 0
            border.color: root.effectiveVariant === "danger" ? Theme.palette.alert : Theme.palette.ruleStrong

            Behavior on color {
                ColorAnimation {
                    duration: Theme.duration("quick")
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.anim.curves.standard
                }
            }
        }

        // Primary/danger hover and press: an ink veil keeps the role fill.
        Rectangle {
            anchors.fill: parent
            radius: surface.radius
            visible: root.effectiveVariant === "primary" || root.effectiveVariant === "danger"
            color: Theme.palette.ink
            opacity: !root.enabled ? 0 : root.down ? 0.16 : root.hovered ? 0.08 : 0
        }

        // Open state: 2 px signal underline toward the surface.
        Rectangle {
            visible: root.open
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: Theme.palette.signal
        }

        // Keyboard-only focus ring: 2 px outside, inside in bars.
        Rectangle {
            anchors.fill: parent
            anchors.margins: root.inBar ? 2 : -2
            radius: Theme.rounding.small + (root.inBar ? 0 : 2)
            color: "transparent"
            border.width: 2
            border.color: Theme.palette.focus
            visible: root.activeFocus && Theme.keyboardFocus && root.enabled
        }
    }
}
