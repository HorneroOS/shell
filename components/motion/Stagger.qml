pragma ComponentBehavior: Bound

import QtQuick

// Row stagger for a scan-in reveal (Signal visual language §11.1 rule 2):
// each row fades in and travels `travel` px from the anchor side with
// `enter`/`short`, starting `Choreography.staggerStart` ms after the frame
// and `staggerStep` ms apart; at most eight rows stagger, later rows start
// with the eighth. Content is never scaled.
//
// Rows are found, not declared: starting at `target`, descend through
// single-child wrappers until a container with two or more visible
// children; those children (in layout order) are the rows. Native popouts and
// extension popovers therefore stagger without opting in.
//
// The reveal never blocks input (rows are live from the first frame) and
// never breaks bindings: animations write through without removing them,
// rows whose opacity is not 1 are only translated, and rows that already
// carry transforms are only faded.
Item {
    id: root

    // Unit vector pointing away from the anchor (Placement travel).
    property real dx: 0
    property real dy: 1
    property real travel: Choreography.scanTravel
    property int duration: Choreography.short
    property list<real> curve: Choreography.curves.enter

    readonly property int poolSize: Choreography.staggerMax + 8
    readonly property bool running: _active > 0
    property int _active: 0

    visible: false

    function rowsOf(target: Item): var {
        let node = target;
        for (let depth = 0; node && depth < 6; depth++) {
            const kids = [];
            // Child order is layout order; geometry may not be polished
            // yet on the frame the content is created.
            for (const c of node.children)
                if (c && c.visible && (c.height > 0 || c.implicitHeight > 0))
                    kids.push(c);
            if (kids.length >= 2)
                return kids;
            if (kids.length === 0)
                return [];
            node = kids[0];
        }
        return [];
    }

    function stop(): void {
        for (let i = 0; i < pool.count; i++) {
            const s = pool.objectAt(i);
            if (s)
                s.finish();
        }
    }

    // Reveal the rows of `target`. Returns how many rows were animated
    // (0 means the caller should reveal the content as one block).
    function play(target: Item): int {
        stop();
        if (!target || !Choreography.stagger)
            return 0;
        const rows = rowsOf(target);
        if (rows.length < 2)
            return 0;
        const n = Math.min(rows.length, pool.count);
        for (let i = 0; i < n; i++)
            pool.objectAt(i)?.start(rows[i], Choreography.rowDelay(i));
        return n;
    }

    Instantiator {
        id: pool

        model: root.poolSize

        delegate: QtObject {
            id: slot

            property Item row: null
            property real fromOpacity: 1
            property bool fades: false
            property bool moves: false

            readonly property Translate shift: Translate {}

            function start(row: Item, delay: int): void {
                slot.row = row;
                slot.fromOpacity = row.opacity;
                slot.fades = row.opacity === 1;
                slot.moves = row.transform.length === 0 || (row.transform.length === 1 && row.transform[0] === slot.shift);
                if (slot.moves && row.transform.length === 0)
                    row.transform = [slot.shift];
                slot.shift.x = slot.moves ? -root.dx * root.travel : 0;
                slot.shift.y = slot.moves ? -root.dy * root.travel : 0;
                if (slot.fades)
                    row.opacity = 0;
                pause.duration = delay;
                root._active++;
                seq.start();
            }

            function finish(): void {
                if (!seq.running)
                    return;
                seq.stop();
                done();
            }

            function done(): void {
                if (slot.row) {
                    if (slot.fades)
                        slot.row.opacity = 1;
                    slot.shift.x = 0;
                    slot.shift.y = 0;
                }
                slot.row = null;
                root._active = Math.max(0, root._active - 1);
            }

            readonly property SequentialAnimation seq: SequentialAnimation {
                onFinished: slot.done()

                PauseAnimation {
                    id: pause
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: slot.row
                        property: "opacity"
                        from: slot.fades ? 0 : slot.fromOpacity
                        to: slot.fades ? 1 : slot.fromOpacity
                        duration: root.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.curve
                    }
                    NumberAnimation {
                        target: slot.shift
                        properties: "x,y"
                        to: 0
                        duration: root.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.curve
                    }
                }
            }
        }
    }
}
