pragma ComponentBehavior: Bound

import ".."
import qs.services
import qs.config
import QtQuick
import QtQuick.Controls

TextField {
    id: root

    color: root.enabled ? Signal.palette.ink : Qt.alpha(Signal.palette.ink, 0.38)
    placeholderTextColor: root.enabled ? Signal.palette.ruleStrong : Qt.alpha(Signal.palette.ruleStrong, 0.38)
    selectionColor: Signal.palette.signal
    selectedTextColor: Signal.palette.onSignal
    font.family: Appearance.font.family.sans
    font.pointSize: Appearance.font.size.smaller
    renderType: echoMode === TextField.Password ? TextField.QtRendering : TextField.NativeRendering
    cursorVisible: !readOnly

    // Tab stays inside the keyboard-holding drawer (FocusMode, #84).
    // Qt runs onTabPressed before onPressed, so fields that route Tab
    // themselves (launcher vim mode) must opt out with trapTab: false.
    property bool trapTab: true

    Keys.onTabPressed: event => {
        if (root.trapTab)
            FocusMode.handleTab(root, event, false);
        else
            event.accepted = false;
    }
    Keys.onBacktabPressed: event => {
        if (root.trapTab)
            FocusMode.handleTab(root, event, true);
        else
            event.accepted = false;
    }

    background: null

    cursorDelegate: StyledRect {
        id: cursor

        property bool disableBlink

        implicitWidth: 2
        color: Signal.palette.signal
        radius: Appearance.rounding.normal

        Connections {
            target: root

            function onCursorPositionChanged(): void {
                if (root.activeFocus && root.cursorVisible) {
                    cursor.opacity = 1;
                    cursor.disableBlink = true;
                    enableBlink.restart();
                }
            }
        }

        Timer {
            id: enableBlink

            interval: 100
            onTriggered: cursor.disableBlink = false
        }

        Timer {
            running: root.activeFocus && root.cursorVisible && !cursor.disableBlink
            repeat: true
            triggeredOnStart: true
            interval: 500
            onTriggered: parent.opacity = parent.opacity === 1 ? 0 : 1
        }

        Binding {
            when: !root.activeFocus || !root.cursorVisible
            cursor.opacity: 0
        }

        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.short
            }
        }
    }

    Behavior on color {
        CAnim {}
    }

    Behavior on placeholderTextColor {
        CAnim {}
    }
}
