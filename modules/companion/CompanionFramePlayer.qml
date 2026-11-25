pragma ComponentBehavior: Bound

import QtQuick
import "companionpacks.js" as Packs

// Native renderer for one sanitized data-only character definition.
// It resolves semantic actions inside the selected skin only; package
// code never runs here. Supports individual frames, layered frames
// and sprite atlases from companionpacks.js descriptors.
Item {
    id: root

    required property var definition
    required property string basePath
    property string skinId: definition ? definition.defaultSkin : "default"
    property string action: "idle"
    property bool playing: true
    property bool reducedMotion: false
    property var accessoryIds: []

    signal finished(string action)

    readonly property var skin: Packs.resolveSkin(definition, skinId)
    readonly property var resolved: Packs.resolveAnimation(definition, skinId, action)
    readonly property var reel: resolved ? resolved.animation : null
    readonly property string resolvedAction: resolved ? resolved.action : ""
    property int frameIndex: 0
    readonly property var frame: {
        if (!root.reel || !root.reel.frames.length)
            return null;
        const still = root.reducedMotion ? (root.reel.reducedMotionFrame || 0) : root.frameIndex;
        return root.reel.frames[Math.max(0, Math.min(root.reel.frames.length - 1, still))];
    }
    readonly property var activeAccessories: {
        if (!root.skin)
            return [];
        return root.skin.accessories.filter(item => root.accessoryIds.indexOf(item.id) >= 0)
            .sort((a, b) => (a.zIndex || 0) - (b.zIndex || 0));
    }

    implicitWidth: definition ? definition.canvas.width : 128
    implicitHeight: definition ? definition.canvas.height : 128

    // End-of-reel handling shared by the timer path and by reels that
    // can never animate (single frame, or reduced motion): without it a
    // one-shot single-frame reel never finishes and the companion
    // freezes in that pose forever (Javi's Player already guards this).
    function completeReel(): void {
        if (!root.reel)
            return;
        frameTimer.stop();
        root.finished(root.resolvedAction);
        if (root.reel.next && root.reel.next !== root.action)
            root.action = root.reel.next;
        else if (root.action !== "idle")
            root.action = "idle";
    }

    function restart(): void {
        root.frameIndex = root.reducedMotion && root.reel ? (root.reel.reducedMotionFrame || 0) : 0;
        frameTimer.restart();
        // The timer only runs for multi-frame reels with motion on, so
        // a non-looping reel that cannot animate must complete here —
        // asynchronously, so action changes do not recurse into restart.
        if (root.playing && root.reel && !root.reel.loop
            && (root.reducedMotion || root.reel.frames.length <= 1))
            Qt.callLater(root.completeReel);
    }

    onActionChanged: restart()
    onSkinIdChanged: restart()
    onDefinitionChanged: restart()
    onPlayingChanged: {
        if (playing)
            frameTimer.restart();
        else
            frameTimer.stop();
    }

    Timer {
        id: frameTimer

        interval: root.frame ? root.frame.ms : 160
        repeat: true
        running: root.playing && !!root.frame && !root.reducedMotion && root.reel && root.reel.frames.length > 1
        onTriggered: {
            if (!root.reel)
                return;
            if (root.frameIndex + 1 < root.reel.frames.length) {
                root.frameIndex += 1;
                return;
            }
            if (root.reel.loop) {
                root.frameIndex = 0;
                return;
            }
            root.completeReel();
        }
    }

    Repeater {
        model: root.frame ? root.frame.layers : []

        Image {
            required property string modelData

            anchors.fill: parent
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: "file://" + root.basePath + "/" + modelData
            sourceClipRect: root.frame && root.frame.clip ? Qt.rect(root.frame.clip[0], root.frame.clip[1], root.frame.clip[2], root.frame.clip[3]) : Qt.rect(0, 0, -1, -1)
            Accessible.ignored: true
        }
    }

    Repeater {
        model: root.activeAccessories

        Image {
            required property var modelData

            anchors.fill: parent
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: "file://" + root.basePath + "/" + modelData.file
            z: 2 + (modelData.zIndex || 0)
            Accessible.ignored: true
        }
    }
}
