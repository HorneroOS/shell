pragma ComponentBehavior: Bound

import qs.config
import qs.services
import Quickshell
import Quickshell.Wayland
import QtQuick

// Native host for validated data-only companions. It creates one
// bounded bottom-layer window per generic instance, never a Loader
// for package entrypoints. Javi keeps its dedicated legacy host.
Scope {
    id: root

    CompanionInstancesPersist {}

    Variants {
        model: CompanionInstances.genericIds

        Scope {
            id: slot

            required property string modelData

            readonly property var instance: CompanionInstances.instanceById(slot.modelData)
            readonly property var character: slot.instance ? CompanionRegistry.characterByKey(slot.instance.characterId) : null
            readonly property var definition: slot.character ? slot.character.definition : null
            readonly property var habitat: slot.definition ? slot.definition.habitat : null
            readonly property var targetScreen: {
                const wanted = slot.instance ? slot.instance.screenName : "";
                const named = Quickshell.screens.find(s => s.name === wanted);
                if (named)
                    return named;
                const focused = Quickshell.screens.find(s => s.name === Compositor.focusedOutputName);
                return focused || Quickshell.screens[0] || null;
            }

            PanelWindow {
                id: win

                readonly property int spriteSize: Math.round(128 * (slot.instance ? slot.instance.scale : 1))
                readonly property real canvasRatio: slot.definition ? slot.definition.canvas.height / slot.definition.canvas.width : 1
                readonly property int spriteW: spriteSize
                readonly property int spriteH: Math.max(32, Math.round(spriteSize * canvasRatio))
                readonly property int habitatW: slot.habitat ? Math.round(spriteSize * 1.7 * slot.habitat.defaultScale) : 0
                readonly property int contentW: Math.max(spriteW, habitatW, bubble.visible ? bubble.implicitWidth : 0)
                readonly property int contentH: Math.max(spriteH, habitatImage.implicitHeight || 0) + (bubble.visible ? bubble.implicitHeight + 8 : 0)
                property int px: 0
                property int py: 0
                property bool positioned: false
                property bool dragging: false
                property real dragStartGlobalX: 0
                property real dragStartGlobalY: 0
                property int dragStartPx: 0
                property int dragStartPy: 0
                property string action: "idle"
                property string bubbleText: ""
                readonly property bool sleeping: CompanionStore.sleepMinutes > 0 && CompanionStore.idleSeconds >= CompanionStore.sleepMinutes * 60

                screen: slot.targetScreen
                visible: !!slot.instance && !!slot.definition && slot.instance.enabled && CompanionStore.enabled && !CompanionStore.suppressed
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "hornero-companion-instance"
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                anchors.left: true
                anchors.top: true
                margins.left: px
                margins.top: py
                implicitWidth: Math.max(1, contentW)
                implicitHeight: Math.max(1, contentH)
                mask: stage

                function placeFromInstance(): void {
                    if (!slot.instance || !win.targetScreen)
                        return;
                    win.px = Math.max(0, Math.min(win.targetScreen.width - win.contentW,
                        Math.round(slot.instance.posX * win.targetScreen.width - win.contentW / 2)));
                    win.py = Math.max(0, Math.min(win.targetScreen.height - win.contentH,
                        Math.round(slot.instance.posY * win.targetScreen.height - win.contentH)));
                    win.positioned = true;
                }

                function commitPosition(): void {
                    if (!slot.instance || !win.targetScreen)
                        return;
                    CompanionInstances.updateInstance(slot.instance.id, {
                        posX: Math.max(0, Math.min(1, (win.px + win.contentW / 2) / Math.max(1, win.targetScreen.width))),
                        posY: Math.max(0, Math.min(1, (win.py + win.contentH) / Math.max(1, win.targetScreen.height))),
                        screenName: win.targetScreen.name
                    });
                }

                function play(nextAction: string, bubble: string): void {
                    if (bubble) {
                        win.bubbleText = bubble;
                        bubbleTimer.restart();
                    }
                    win.action = nextAction;
                    sprite.restart();
                }

                onContentWChanged: if (!dragging)
                    placeFromInstance()
                onContentHChanged: if (!dragging)
                    placeFromInstance()
                Component.onCompleted: placeFromInstance()

                Connections {
                    target: slot.instance ? CompanionInstances : null

                    function onReactionRequested(instanceId: string, animation: string, bubble: string): void {
                        if (instanceId === slot.modelData)
                            win.play(animation, bubble);
                    }
                }

                Connections {
                    target: slot.instance ? CompanionStore : null

                    function onScreenNameChanged(): void {
                    }
                }

                Timer {
                    id: bubbleTimer

                    interval: 4200
                    onTriggered: win.bubbleText = ""
                }

                Timer {
                    id: idleTimer

                    interval: 18000
                    repeat: true
                    running: win.visible && !win.sleeping && !CompanionStore.reducedMotion && CompanionStore.idleAnimEnabled
                    onTriggered: {
                        interval = 14000 + Math.floor(Math.random() * 18000);
                        if (win.action !== "idle")
                            return;
                        const candidates = ["blink", "look", "stretch", "greet"].filter(a => {
                            const resolved = sprite.definition;
                            return resolved && sprite.skin && sprite.skin.animations[a];
                        });
                        if (candidates.length)
                            win.play(candidates[Math.floor(Math.random() * candidates.length)], "");
                    }
                }

                Item {
                    id: stage

                    anchors.fill: parent

                    Image {
                        id: habitatImage

                        visible: !!slot.habitat && slot.instance && slot.instance.habitatEnabled
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: win.habitatW
                        height: implicitWidth > 0 ? width * implicitHeight / implicitWidth : 0
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: visible ? "file://" + slot.character.basePath + "/" + slot.habitat.image : ""
                        Accessible.ignored: true
                    }

                    CompanionFramePlayer {
                        id: sprite

                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: win.spriteW
                        height: win.spriteH
                        definition: slot.definition
                        basePath: slot.character ? slot.character.basePath : ""
                        skinId: slot.instance ? slot.instance.skin : "default"
                        action: win.sleeping ? "sleep" : win.action
                        playing: win.visible
                        reducedMotion: Appearance.anim.reduced || CompanionStore.reducedMotion
                        accessoryIds: slot.instance ? slot.instance.accessories : []
                        scale: (win.px + win.contentW / 2) > (win.targetScreen ? win.targetScreen.width / 2 : 0) ? -1 : 1
                        Accessible.role: Accessible.Graphic
                        Accessible.name: slot.character ? CompanionRegistry.displayName(slot.character) : ""
                        onFinished: action => {
                            if (action !== "idle")
                                win.action = "idle";
                        }
                    }

                    Bubble {
                        id: bubble

                        visible: win.bubbleText !== ""
                        anchors.bottom: sprite.top
                        anchors.bottomMargin: 8
                        anchors.horizontalCenter: sprite.horizontalCenter
                        text: win.bubbleText
                        theme: CompanionStore.bubbleTheme === "auto" ? (Signal.light ? "light" : "dark") : CompanionStore.bubbleTheme
                        flip: (win.px + win.contentW / 2) > (win.targetScreen ? win.targetScreen.width / 2 : 0)
                    }

                    MouseArea {
                        anchors.fill: sprite
                        acceptedButtons: Qt.LeftButton
                        cursorShape: win.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: mouse => {
                            const global = sprite.mapToGlobal(mouse.x, mouse.y);
                            win.dragStartGlobalX = global.x;
                            win.dragStartGlobalY = global.y;
                            win.dragStartPx = win.px;
                            win.dragStartPy = win.py;
                            win.dragging = true;
                        }
                        onPositionChanged: mouse => {
                            if (!win.dragging)
                                return;
                            const global = sprite.mapToGlobal(mouse.x, mouse.y);
                            win.px = Math.max(0, Math.min(win.targetScreen.width - win.contentW, win.dragStartPx + global.x - win.dragStartGlobalX));
                            win.py = Math.max(0, Math.min(win.targetScreen.height - win.contentH, win.dragStartPy + global.y - win.dragStartGlobalY));
                        }
                        onReleased: mouse => {
                            const moved = Math.abs(win.px - win.dragStartPx) + Math.abs(win.py - win.dragStartPy) > 6;
                            win.dragging = false;
                            win.commitPosition();
                            if (!moved)
                                win.play("greet", "");
                        }
                    }
                }
            }
        }
    }
}
