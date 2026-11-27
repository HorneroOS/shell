import QtQuick

// The Hornero symbolic mark (assets/mark.svg: a setting-sun disc cut by
// two horizon bars), drawn once in any colour. Kept local so the reload
// cover stays dependency-free; repaints only when size or colour change.
Canvas {
    id: root

    property real size: 48
    property color color: "#F2AC52"

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    Accessible.ignored: true

    onColorChanged: requestPaint()
    onSizeChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const k = width / 24;
        ctx.reset();
        ctx.save();
        ctx.beginPath();
        ctx.arc(12 * k, 12 * k, 9.5 * k, 0, 2 * Math.PI);
        ctx.clip();
        ctx.fillStyle = root.color;
        // Same bands as mark.svg's viewBox 0 0 24 24.
        ctx.fillRect(0, 2.5 * k, 24 * k, 5.85 * k);
        ctx.fillRect(0, 10.1 * k, 24 * k, 3.8 * k);
        ctx.fillRect(0, 15.65 * k, 24 * k, 5.85 * k);
        ctx.restore();
    }
}
