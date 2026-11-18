pragma ComponentBehavior: Bound

import qs.components.motion
import qs.services
import qs.config
import QtQuick
import "Placement.js" as Placement

// One anchored surface (RFC 0001 §4, Signal visual language §7, §11.1):
// placement from the shared solver, a live anchor, the morphing frame and
// the open / switch / close choreography. Bar popouts, tray menus,
// tooltips and extension popovers are all instances of this; none of
// them positions or animates itself.
//
// The item's own x/y/width/height ARE the animated frame, in the parent's
// coordinates, so input masks and hit tests that read the item follow the
// frame exactly. Content goes into SurfacePage children: each page pins
// itself to the placement it was revealed with, so the frame can morph
// and clip around it without the content moving, scaling or reflowing.
//
// Choreography (motion level from Choreography):
//   open    frame grows from the trigger notch (trigger-wide, zero depth
//           on the anchor line) to the final rect: settle 320 ms (hover
//           opens settleFast 220 ms); frame opacity enter 90 ms; pages
//           scan in, rows staggered 24 ms from 60 ms.
//   switch  `key` changes while open: the frame morphs from its current
//           rect to the new one (settle 320 ms); the old page fades out in
//           90 ms, the new one fades in (enter 160 ms), no stagger.
//   track   the anchor or the content size changes: re-solve and follow
//           with settleFast from wherever the frame is (no teleport).
//   close   frame and content fade together with 4 px travel toward the
//           anchor, exit 90 ms. No reverse morph.
// Reduced: no morph or stagger, 4 px travel + fade. Off: instant, opacity
// fades capped at 90 ms. Surfaces are interactive from their first frame.
Item {
    id: root

    // ---- Inputs ----

    // The trigger. Its rect is tracked live through every ancestor.
    property Item anchorItem: null
    // Centred surfaces (detached windows) ignore the anchor.
    property bool centred: false
    // Owning bar: {edge, style, thickness, margin, floating, clear} or
    // null. `ownerItem` (optional) is the bar's slab; its live rect
    // becomes owner.rect so the anchor line follows bar animations.
    property var owner: null
    property Item ownerItem: null
    // For surfaces not owned by a bar: "below" | "above" | "right" | "left".
    property string preferredSide: "below"
    // The screen in parent coordinates, its device pixel ratio and the
    // logical px reserved on each edge (bars, frame).
    property rect bounds: Qt.rect(0, 0, parent ? parent.width : 0, parent ? parent.height : 0)
    property real devicePixelRatio: 1
    property var reserved: ({})
    property real gutter: 8
    property real gap: 4
    // Preferred (content) size of the surface, including its padding.
    property real preferredWidth: 0
    property real preferredHeight: 0
    // Open state, how it was opened ("hover" | "click" | "keyboard") and
    // the content identity (a change while open morphs).
    property bool open: false
    property string intent: "click"
    property string key: ""
    // Draws the registration tick.
    property bool keyboardFocused: false
    property bool notch: true
    // Frame morph from the trigger notch on open. Tooltips do not morph:
    // they fade with 4 px travel from the anchor (visual language §11.2).
    property bool morphs: true
    property int travelDuration: Choreography.brief
    property int elevation: 2
    property color fill: Signal.palette.panel
    property real radius: Appearance.rounding.small
    // Machined fillet at an attached junction (SurfaceFrame), 0 = flush,
    // and the junction outline's offset from the anchor line.
    property real fillet: 0
    property real filletRule: 0

    // ---- Outputs ----

    readonly property rect anchorRect: anchorTracker.rect
    readonly property var placement: Placement.solve({
        trigger: root.centred ? null : root._trigger,
        bar: root._owner,
        preferredSide: root.preferredSide,
        previousSide: root._lastSide,
        screen: {
            x: root.bounds.x,
            y: root.bounds.y,
            width: root.bounds.width,
            height: root.bounds.height,
            scale: root.devicePixelRatio,
            reserved: root.reserved
        },
        size: {
            width: root.preferredWidth,
            height: root.preferredHeight
        },
        gutter: root.gutter,
        gap: root.gap
    })
    readonly property rect target: Qt.rect(placement.x, placement.y, placement.width, placement.height)
    readonly property string edge: placement.edge
    // closed | opening | open | closing
    property string phase: "closed"
    readonly property bool shown: phase !== "closed"
    readonly property bool animating: frameAnim.running || fadeAnim.running || travelAnim.running

    default property alias content: pageHost.data
    readonly property alias pageHost: pageHost
    readonly property alias frame: frameItem

    signal revealed
    signal closed

    // ---- Page reveal bookkeeping (SurfacePage) ----

    // "open" | "hover" | "switch" for the page `key` becoming current.
    function claimReveal(pageKey: string): string {
        const fresh = root._revealedKey === "" || root.phase === "closed" || root.phase === "closing";
        root._revealedKey = pageKey;
        if (fresh)
            return root.intent === "hover" ? "hover" : "open";
        return "switch";
    }

    // ---- Internals ----

    property rect _lastTrigger: Qt.rect(0, 0, 0, 0)
    property string _lastSide: ""
    property string _revealedKey: ""
    property rect _applied: Qt.rect(0, 0, 0, 0)
    property bool _morphing: false

    readonly property rect _trigger: anchorTracker.valid ? anchorTracker.rect : _lastTrigger
    readonly property var _owner: {
        const o = root.owner;
        if (!o)
            return null;
        const r = ownerTracker.valid ? ownerTracker.rect : null;
        return {
            edge: o.edge,
            style: o.style,
            thickness: o.thickness,
            margin: o.margin,
            floating: o.floating,
            clear: o.clear,
            rect: r ? {
                x: r.x,
                y: r.y,
                width: r.width,
                height: r.height
            } : null
        };
    }

    function _near(a: rect, b: rect): bool {
        return Math.abs(a.x - b.x) < 0.5 && Math.abs(a.y - b.y) < 0.5 && Math.abs(a.width - b.width) < 0.5 && Math.abs(a.height - b.height) < 0.5;
    }

    // Past ~8 px of overshoot use `enter` instead (visual language §11).
    // The overshoot fraction follows the curve style (smooth: settle
    // 1.9 %, settleFast 3 %; lively: 5.3 % / 5.8 %; snappy: none).
    function _curveFor(fast: bool, travel: real): var {
        const c = Choreography.curves;
        if (fast)
            return travel * c.settleFastOvershoot > 8 ? c.enter : c.settleFast;
        return travel * c.settleOvershoot > 8 ? c.enter : c.settle;
    }

    function _setGeometry(r: rect): void {
        root.x = r.x;
        root.y = r.y;
        root.width = r.width;
        root.height = r.height;
    }

    function _animateTo(t: rect, fast: bool): void {
        frameAnim.stop();
        const dur = fast ? Choreography.settleFast : Choreography.settle;
        if (dur <= 0) {
            _setGeometry(t);
            return;
        }
        const travel = Math.max(Math.abs(t.x - root.x), Math.abs(t.y - root.y), Math.abs(t.width - root.width), Math.abs(t.height - root.height));
        if (travel < 0.5) {
            _setGeometry(t);
            return;
        }
        const curve = _curveFor(fast, travel);
        for (const a of [ax, ay, aw, ah]) {
            a.duration = dur;
            a.easing.bezierCurve = curve;
        }
        ax.to = t.x;
        ay.to = t.y;
        aw.to = t.width;
        ah.to = t.height;
        frameAnim.start();
    }

    function _onTarget(): void {
        if (!root.shown || root.phase === "closing")
            return;
        const t = root.target;
        if (_near(t, root._applied))
            return;
        root._applied = t;
        // A morph in flight keeps its spring; everything else follows fast.
        _animateTo(t, !root._morphing);
    }

    function _begin(): void {
        exitAnim.stop();
        if (root.phase === "closing") {
            // Reopened while fading out: carry on from where the frame is.
            root.phase = "open";
            root._morphing = true;
            root._applied = root.target;
            _animateTo(root.target, false);
            fadeAnim.from = root.opacity;
            fadeAnim.to = 1;
            fadeAnim.restart();
            travel.x = 0;
            travel.y = 0;
            return;
        }
        if (root.phase !== "closed")
            return;
        root.phase = "opening";
        root._lastSide = "";
        const p = root.placement;
        const t = root.target;
        root._applied = t;
        const hover = root.intent === "hover";
        travel.x = 0;
        travel.y = 0;
        if (Choreography.morph && root.morphs && p.side !== "center") {
            const s = Placement.seedRect(p);
            _setGeometry(Qt.rect(s.x, s.y, s.width, s.height));
            root._morphing = !hover;
            _animateTo(t, hover);
        } else {
            _setGeometry(t);
            if (Choreography.travel && p.side !== "center") {
                // No morph (reduced level, tooltips): 4 px travel from the
                // anchor side plus the fade.
                travelAnim.stop();
                travel.x = -p.travel.dx * Choreography.scanTravel;
                travel.y = -p.travel.dy * Choreography.scanTravel;
                travelAnim.start();
            }
        }
        fadeAnim.from = 0;
        fadeAnim.to = 1;
        root.opacity = 0;
        fadeAnim.restart();
        root.revealed();
    }

    function _end(): void {
        if (root.phase === "closed" || root.phase === "closing")
            return;
        root.phase = "closing";
        fadeAnim.stop();
        travelAnim.stop();
        // Travel back toward the anchor: against the placement's travel.
        const p = root.placement;
        exitTravelX.to = -p.travel.dx * Choreography.exitTravel;
        exitTravelY.to = -p.travel.dy * Choreography.exitTravel;
        exitAnim.start();
    }

    function _finishClose(): void {
        frameAnim.stop();
        // A closed surface has no extent: input masks built from it must
        // not keep swallowing clicks where it was.
        root.width = 0;
        root.height = 0;
        root.phase = "closed";
        root._revealedKey = "";
        root._morphing = false;
        root._lastSide = "";
        travel.x = 0;
        travel.y = 0;
        root.closed();
    }

    visible: shown && width > 0 && height > 0
    opacity: 0

    onOpenChanged: open ? _begin() : _end()
    onTargetChanged: _onTarget()
    onKeyChanged: {
        if (root.phase === "opening" || root.phase === "open") {
            root._morphing = true;
            root._applied = Qt.rect(-1, -1, -1, -1);
            _onTarget();
        }
    }
    onPlacementChanged: {
        if (root.shown && placement.side !== "center")
            root._lastSide = placement.side;
    }
    on_TriggerChanged: {
        // Remember the last live rect: a trigger destroyed mid-close (bar
        // reload) must not teleport the fading surface.
        if (anchorTracker.valid)
            root._lastTrigger = anchorTracker.rect;
    }
    Component.onCompleted: {
        if (root.open)
            _begin();
    }

    transform: Translate {
        id: travel
    }

    AnchorTracker {
        id: anchorTracker

        item: root.anchorItem
        root: root.parent
    }

    AnchorTracker {
        id: ownerTracker

        item: root.ownerItem
        root: root.parent
    }

    ParallelAnimation {
        id: frameAnim

        onFinished: {
            root._morphing = false;
            if (root.phase === "opening")
                root.phase = "open";
        }

        NumberAnimation {
            id: ax

            target: root
            property: "x"
            easing.type: Easing.BezierSpline
        }
        NumberAnimation {
            id: ay

            target: root
            property: "y"
            easing.type: Easing.BezierSpline
        }
        NumberAnimation {
            id: aw

            target: root
            property: "width"
            easing.type: Easing.BezierSpline
        }
        NumberAnimation {
            id: ah

            target: root
            property: "height"
            easing.type: Easing.BezierSpline
        }
    }

    // Frame opacity 0 -> 1 with enter (90 ms); never a settle curve.
    NumberAnimation {
        id: fadeAnim

        target: root
        property: "opacity"
        duration: Choreography.fade
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Choreography.curves.enter
        onFinished: {
            if (root.phase === "opening" && !frameAnim.running)
                root.phase = "open";
        }
    }

    NumberAnimation {
        id: travelAnim

        target: travel
        properties: "x,y"
        to: 0
        duration: root.travelDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Choreography.curves.enter
    }

    // Close: fade plus 4 px travel back toward the anchor, exit 90 ms.
    ParallelAnimation {
        id: exitAnim

        onFinished: root._finishClose()

        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: Choreography.fade
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Choreography.curves.exit
        }
        NumberAnimation {
            id: exitTravelX

            target: travel
            property: "x"
            duration: Choreography.quick
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Choreography.curves.exit
        }
        NumberAnimation {
            id: exitTravelY

            target: travel
            property: "y"
            duration: Choreography.quick
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Choreography.curves.exit
        }
    }

    SurfaceFrame {
        id: frameItem

        anchors.fill: parent
        edge: root.placement.edge
        attached: root.placement.attached
        fill: root.fill
        radius: root.radius
        fillet: root.fillet
        filletRule: root.filletRule
        elevation: root.elevation
        focused: root.keyboardFocused
        // The notch follows the live trigger, not the final rect, so it
        // stays under the trigger while the frame morphs.
        notchVisible: root.notch && root.placement.side !== "center" && notchLength > 0
        notchStart: {
            const horizontal = edge === "top" || edge === "bottom";
            const start = horizontal ? root._trigger.x - root.x : root._trigger.y - root.y;
            return Math.max(0, start);
        }
        notchLength: {
            const horizontal = edge === "top" || edge === "bottom";
            const start = horizontal ? root._trigger.x - root.x : root._trigger.y - root.y;
            const len = horizontal ? root._trigger.width : root._trigger.height;
            const extent = horizontal ? root.width : root.height;
            const s = Math.max(0, start);
            const e = Math.min(extent, start + len);
            return Math.max(0, e - s);
        }
    }

    // Clip from the anchor edge: the frame is the reveal mask.
    Item {
        anchors.fill: parent
        clip: true

        Item {
            id: pageHost

            width: root.width
            height: root.height
        }
    }
}
