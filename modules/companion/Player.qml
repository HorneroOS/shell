pragma ComponentBehavior: Bound

import QtQuick

// Reusable frame player: exactly one Timer core advances the frame
// list. Single-frame (or empty) animations never run the timer, so an
// idling companion costs nothing. Emits finished() when a non-looping
// animation plays through; looping animations run until paused,
// stopped, or given new frames.
Item {
    id: root

    // Full file paths (or qrc/source URLs) of the current animation.
    property list<string> frames: []
    // Optional per-frame durations (ms); missing entries use frameMs.
    property list<int> durations: []
    // Shown when frames is empty; never blank.
    property string fallbackFrame: ""
    property int frameMs: 900
    property bool loop: true
    property bool playing: true
    property bool paused: false
    // Reduced motion: hold frame 0 of every reel, never advance.
    property bool holdStill: false
    property int currentIndex: 0

    signal finished()

    readonly property bool advancing: root.playing && !root.paused && !root.holdStill && root.frames.length > 1
    readonly property string currentFrame: root.frames.length > 0 ? root.frames[Math.min(root.currentIndex, root.frames.length - 1)] : root.fallbackFrame
    readonly property string nextFrame: root.frames.length > 1 ? root.frames[(root.currentIndex + 1) % root.frames.length] : root.currentFrame
    readonly property int currentMs: {
        const d = root.durations[Math.min(root.currentIndex, root.frames.length - 1)];
        return (typeof d === "number" && d >= 80) ? d : root.frameMs;
    }

    function restart(): void {
        root.currentIndex = 0;
    }

    // Swap animation reels (resets to the first frame). Called by the
    // host whenever skin or animation changes. durations is optional.
    function setReel(frames: list<string>, frameMs: int, loop: bool, durations: list<int>): void {
        root.frames = frames;
        root.frameMs = (frameMs ?? 0) > 0 ? frameMs : 900;
        root.loop = loop ?? true;
        root.durations = durations ?? [];
        root.restart();
        // Single-frame (or empty) non-looping reels never run the timer,
        // so finished() would never fire and a one-shot override would
        // stick forever. Complete asynchronously instead.
        if (!root.loop && root.frames.length <= 1)
            Qt.callLater(root.finished);
    }

    Timer {
        id: advanceTimer

        interval: root.currentMs
        repeat: true
        running: root.advancing
        triggeredOnStart: false

        onTriggered: {
            if (root.currentIndex >= root.frames.length - 1) {
                if (root.loop) {
                    root.currentIndex = 0;
                } else {
                    root.playing = false;
                    root.finished();
                }
            } else {
                root.currentIndex = root.currentIndex + 1;
            }
        }
    }

    onFramesChanged: {
        if (root.currentIndex >= root.frames.length)
            root.currentIndex = 0;
    }
}
