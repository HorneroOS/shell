import QtQuick

// Ring buffer of real samples for a scope or sparkline. `sample()` appends
// a real value (NaN is dropped, never interpolated). `samples` is the
// current window; `persistence` is the window before it (Signal Bezel
// §6.4: drawn faintly as real data one window old).
QtObject {
    id: root

    property int length: 60
    property var _all: []
    readonly property var samples: _all.length > length ? _all.slice(_all.length - length) : _all
    readonly property var persistence: _all.length > length ? _all.slice(0, _all.length - length) : []

    function sample(v: real): void {
        if (isNaN(v))
            return;
        const next = root._all.concat([v]);
        while (next.length > root.length * 2)
            next.shift();
        root._all = next;
    }
}
