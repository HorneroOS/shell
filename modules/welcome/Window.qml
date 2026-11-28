pragma ComponentBehavior: Bound

import qs.components
import qs.components.atmosphere
import qs.components.controls
import qs.components.motion
import qs.modules.welcome
import qs.modules.welcome as WelcomeModule
import qs.modules.welcome.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Hornero Welcome 3-mode editorial window ("Signal Flight — Editorial Observatory").
// Hosts Mode 1 (First Flight, 9 lazy-loaded scenes), Mode 2 (Explore Hornero),
// and Mode 3 (What's New), with pause-when-hidden and full keyboard navigation.
FloatingWindow {
    id: win

    title: qsTr("Hornero Welcome")
    color: Signal.palette.base

    implicitWidth: 1080
    implicitHeight: 680
    minimumSize.width: 960
    minimumSize.height: 600
    visible: true

    readonly property bool windowActive: win.visible && Qt.application.state === Qt.ApplicationActive
    property bool _navReady: false

    readonly property var sceneFiles: ({
            "arrival": "scenes/ArrivalScene.qml",
            "personalize": "scenes/PersonalizeScene.qml",
            "workstation": "scenes/WorkstationScene.qml",
            "companion": "scenes/CompanionScene.qml",
            "practice": "scenes/PracticeScene.qml",
            "extensions": "scenes/ExtensionsScene.qml",
            "showcase": "scenes/ShowcaseScene.qml",
            "trust": "scenes/TrustScene.qml",
            "ready": "scenes/ReadyScene.qml"
        })

    readonly property string activeContentSource: {
        if (Welcome.mode === "explore")
            return "views/ExploreView.qml";
        if (Welcome.mode === "whats-new")
            return "views/WhatsNewView.qml";
        return win.sceneFiles[Welcome.currentScene] ?? "scenes/ArrivalScene.qml";
    }

    onVisibleChanged: {
        if (!visible && Welcome.opened)
            Welcome.close();
    }

    Behavior on color {
        CAnim {}
    }

    Shortcut {
        sequences: ["Escape"]
        context: Qt.WindowShortcut
        onActivated: Welcome.close()
    }

    Shortcut {
        sequences: ["Alt+Left"]
        context: Qt.WindowShortcut
        onActivated: {
            if (Welcome.mode === "first-flight")
                Welcome.prevScene();
        }
    }

    Shortcut {
        sequences: ["Alt+Right"]
        context: Qt.WindowShortcut
        onActivated: {
            if (Welcome.mode === "first-flight")
                Welcome.nextScene();
        }
    }

    Component.onCompleted: {
        win._navReady = true;
    }

    AtmosphereTexture {}

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        WelcomeChrome {
            id: chrome

            currentMode: Welcome.mode
            hasUnseenWhatsNew: WelcomeModule.State.hasUnseenRelease
        }

        // Lazy-loaded editorial stage with Signal motion tokens
        Item {
            id: stage

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Loader {
                id: sceneLoader

                anchors.fill: parent
                source: Qt.resolvedUrl(win.activeContentSource)
                asynchronous: false

                onLoaded: {
                    if (item && item.hasOwnProperty("windowActive"))
                        item.windowActive = Qt.binding(() => win.windowActive);
                    stageEnter.restart();
                }
            }

            ParallelAnimation {
                id: stageEnter

                NumberAnimation {
                    target: sceneLoader
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: Appearance.anim.reduced
                        ? Choreography.reducedFadeMs
                        : Math.max(Choreography.reducedFadeMs, Choreography.effectiveDuration(Choreography.standardMs, Appearance.anim.reduced))
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Choreography.curves.enter
                }

                NumberAnimation {
                    target: sceneLoader
                    property: "x"
                    from: Welcome.navDirection * Choreography.effectiveTravel(Choreography.sceneTravelPx, Appearance.anim.reduced)
                    to: 0
                    duration: Choreography.effectiveDuration(Choreography.sceneMs, Appearance.anim.reduced)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Choreography.curves.enter
                }
            }
        }

        FlightRail {
            currentScene: Welcome.currentScene
            sceneIndex: Welcome.sceneIndex
        }
    }

    // Hosted in WelcomeChrome's trailing slot so Close Welcome stays owned by Window.qml.
    IconButton {
        parent: chrome.trailingSlotTarget ?? win.contentItem
        anchors.centerIn: parent
        type: IconButton.Text
        icon: "x"
        accessibleName: qsTr("Close Welcome")
        onClicked: Welcome.close()
    }

    AtmosphereLayer {
        lampOrigin: "topRight"
        lampReach: 1.0
    }
}
