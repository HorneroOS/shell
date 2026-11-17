pragma ComponentBehavior: Bound

import qs.components
import qs.components.motion
import qs.services
import qs.config
import QtQuick

// One content page of an AnchoredSurface (a bar popout, a tray menu, an
// extension popover body). While current, the page pins itself to the
// surface's final placement (inset by its padding); after it stops being
// current it keeps that pin while it fades, so the frame can morph to
// the next page around it without the old content moving.
//
// Reveal (Signal visual language §11.1):
//   open    rows scan in: 4 px travel from the anchor side and fade,
//           enter 160 ms, staggered 24 ms from 60 ms (Stagger). Content
//           that has no rows reveals as one block.
//   hover   one block, no stagger.
//   switch  fade in with enter 160 ms, no stagger; the outgoing page
//           fades out in 90 ms.
// Content scrolls when the solver had to clamp the surface (RFC §4 rule 2).
Item {
    id: page

    required property Item surface
    property bool current: false
    property string pageKey: ""
    property real hPadding: 16
    property real vPadding: 12
    // Bezel header (visual language §7.1): eyebrow with an optional
    // channel number on the left ("01 · AUDIO"), context on the right.
    property string eyebrow: ""
    property string context: ""
    readonly property real headerHeight: eyebrow.length > 0 ? header.implicitHeight + 8 : 0
    // Unload the content once hidden (default) or keep it alive.
    property bool keepLoaded: false

    property alias sourceComponent: loader.sourceComponent
    readonly property alias item: loader.item
    readonly property alias loader: loader

    // Content size the host feeds into the surface's preferred size.
    readonly property real contentWidth: loader.implicitWidth
    readonly property real contentHeight: loader.implicitHeight
    readonly property real preferredWidth: contentWidth + hPadding * 2
    readonly property real preferredHeight: contentHeight + headerHeight + vPadding * 2

    property rect pin: Qt.rect(0, 0, 0, 0)

    function _syncPin(): void {
        const t = page.surface.target;
        page.pin = Qt.rect(t.x + page.hPadding, t.y + page.vPadding, Math.max(0, t.width - page.hPadding * 2), Math.max(0, t.height - page.vPadding * 2));
    }

    function _reveal(): void {
        leaveAnim.stop();
        revealAnim.stop();
        stagger.stop();
        loader.active = true;
        _syncPin();
        const p = page.surface.placement;
        const kind = page.surface.claimReveal(page.pageKey);
        stagger.dx = p.travel.dx;
        stagger.dy = p.travel.dy;
        if (kind === "switch") {
            shift.x = 0;
            shift.y = 0;
            revealPause.duration = 0;
            revealFade.duration = Choreography.fadeIn;
            page.opacity = 0;
            revealAnim.start();
            return;
        }
        if (kind === "open" && loader.item) {
            page.opacity = 1;
            shift.x = 0;
            shift.y = 0;
            if (stagger.play(loader.item) > 0)
                return;
        }
        // One block: scan-in travel from the anchor side and fade.
        shift.x = -p.travel.dx * Choreography.scanTravel;
        shift.y = -p.travel.dy * Choreography.scanTravel;
        revealPause.duration = kind === "open" ? Choreography.staggerStart : 0;
        revealFade.duration = Choreography.fadeIn;
        page.opacity = 0;
        revealAnim.start();
    }

    function _leave(): void {
        revealAnim.stop();
        stagger.stop();
        if (page.surface.open) {
            // Switching: fade out in place (exit 90 ms) while the frame morphs.
            leaveAnim.start();
        }
        // Closing as a whole: the surface fades; reset when it is closed.
    }

    function _unload(): void {
        page.opacity = 0;
        shift.x = 0;
        shift.y = 0;
        if (!page.keepLoaded && !page.current)
            loader.active = false;
    }

    x: pin.x - surface.x
    y: pin.y - surface.y
    width: pin.width
    height: pin.height
    implicitWidth: contentWidth
    implicitHeight: contentHeight
    opacity: 0
    visible: opacity > 0
    // A fading-out page never takes input from the incoming one.
    enabled: current

    onCurrentChanged: current ? _reveal() : _leave()
    Component.onCompleted: {
        if (current)
            _reveal();
    }

    transform: Translate {
        id: shift
    }

    Connections {
        target: page.surface
        enabled: page.current

        function onTargetChanged(): void {
            page._syncPin();
        }
    }

    Connections {
        target: page.surface

        function onClosed(): void {
            page._unload();
        }
    }

    SequentialAnimation {
        id: revealAnim

        PauseAnimation {
            id: revealPause
        }
        ParallelAnimation {
            NumberAnimation {
                id: revealFade

                target: page
                property: "opacity"
                to: 1
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Choreography.curves.enter
            }
            NumberAnimation {
                target: shift
                properties: "x,y"
                to: 0
                duration: Choreography.brief
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Choreography.curves.enter
            }
        }
    }

    NumberAnimation {
        id: leaveAnim

        target: page
        property: "opacity"
        to: 0
        duration: Choreography.fade
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Choreography.curves.exit
        onFinished: page._unload()
    }

    Stagger {
        id: stagger
    }

    Item {
        id: header

        visible: page.eyebrow.length > 0
        width: parent.width
        implicitHeight: eyebrowText.implicitHeight

        StyledText {
            id: eyebrowText

            anchors.left: parent.left
            text: page.eyebrow.toUpperCase()
            color: Signal.palette.inkMuted
            font.family: Appearance.font.family.mono
            font.pointSize: Appearance.font.size.small
            font.letterSpacing: 1
        }

        StyledText {
            anchors.right: parent.right
            anchors.left: eyebrowText.right
            anchors.leftMargin: 12
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: page.context.toUpperCase()
            color: Signal.palette.inkMuted
            font.family: Appearance.font.family.mono
            font.pointSize: Appearance.font.size.small
            font.letterSpacing: 1
        }
    }

    Flickable {
        id: flick

        anchors.fill: parent
        anchors.topMargin: page.headerHeight
        contentWidth: width
        contentHeight: loader.implicitHeight
        interactive: contentHeight > height + 1
        clip: interactive
        boundsBehavior: Flickable.StopAtBounds

        Loader {
            id: loader

            active: false
        }
    }
}
