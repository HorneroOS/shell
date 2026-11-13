// Keyboard-only QA fixture for the PluginKit accessibility contract
// (#376). Run offscreen by tests/test_pluginkit_ui.py with a stub
// Theme (the real Theme singleton binds shell singletons that do
// not exist outside quickshell; the stub mirrors the same property
// names, including reducedMotion/animationScale/motionDuration).
// This proves the QML-level contract only: real compositor focus
// grabs and AT-SPI announcements are NOT covered here.
import QtQuick
import QtTest
import Hornero.PluginKit

Item {
    id: win
    width: 480; height: 360
    property int clicks: 0
    property int popClicks: 0

    Column {
        anchors.fill: parent
        spacing: 8
        UiButton {
            id: btn
            text: "Refresh"
            accessibleName: "Refresh data"
            tooltipText: "Reload data"
            onClicked: win.clicks++
        }
        UiToggle {
            id: tog
            text: "Enabled"
            accessibleName: "Enabled toggle"
        }
        UiSlider {
            id: sld
            accessibleName: "Level"
            from: 0; to: 100; value: 50
            width: 220
        }
        UiButton {
            id: disabledBtn
            text: "Disabled"
            enabled: false
        }
        UiButton {
            id: trigger
            text: "More"
            accessibleName: "More details"
            onClicked: pop.toggle()
        }
    }
    UiPopover {
        id: pop
        target: trigger
        accessibleName: "Details panel"
        Column {
            spacing: 6
            UiButton {
                id: popBtn
                text: "Apply"
                onClicked: { win.popClicks++; pop.close() }
            }
            UiToggle {
                id: popTog
                text: "Inner"
            }
        }
    }

    TestCase {
        name: "PluginKitKeyboard"
        when: windowShown

        function test_accessible_names_and_tab_stops() {
            compare(btn.Accessible.name, "Refresh data")
            compare(btn.Accessible.role, Accessible.Button)
            compare(btn.Accessible.description, "Reload data")
            compare(tog.Accessible.name, "Enabled toggle")
            compare(tog.Accessible.role, Accessible.CheckBox)
            compare(sld.Accessible.name, "Level")
            compare(sld.Accessible.role, Accessible.Slider)
            verify(btn.activeFocusOnTab, "UiButton is a tab stop while enabled")
            verify(tog.activeFocusOnTab, "UiToggle is a tab stop while enabled")
            verify(sld.activeFocusOnTab, "UiSlider is a tab stop while enabled")
            verify(!disabledBtn.activeFocusOnTab, "disabled control is not a tab stop")
        }

        function test_button_and_toggle_keys() {
            win.clicks = 0
            btn.forceActiveFocus()
            verify(btn.activeFocus)
            keyClick(Qt.Key_Space)
            compare(win.clicks, 1, "Space activates UiButton")
            keyClick(Qt.Key_Return)
            compare(win.clicks, 2, "Return activates UiButton")
            keyClick(Qt.Key_Enter)
            compare(win.clicks, 3, "Enter activates UiButton")

            keyClick(Qt.Key_Tab)
            verify(tog.activeFocus, "Tab follows declaration order btn -> tog")
            const was = tog.checked
            keyClick(Qt.Key_Space)
            verify(tog.checked !== was, "Space toggles UiToggle")
            keyClick(Qt.Key_Return)
            verify(tog.checked === was, "Return toggles UiToggle")
        }

        function test_slider_keys() {
            sld.value = 50
            sld.forceActiveFocus()
            verify(sld.activeFocus)
            keyClick(Qt.Key_Right)
            compare(sld.value, 55, "Right steps by range/20")
            keyClick(Qt.Key_Left)
            compare(sld.value, 50, "Left steps back")
            keyClick(Qt.Key_PageUp)
            compare(sld.value, 60, "PageUp steps by range/10")
            keyClick(Qt.Key_PageDown)
            compare(sld.value, 50, "PageDown steps back")
            keyClick(Qt.Key_Home)
            compare(sld.value, 0, "Home jumps to minimum")
            keyClick(Qt.Key_End)
            compare(sld.value, 100, "End jumps to maximum")
        }

        function test_popover_keyboard_flow() {
            trigger.forceActiveFocus()
            verify(trigger.activeFocus)
            keyClick(Qt.Key_Space)
            tryCompare(pop, "opened", true)
            wait(200)
            verify(popBtn.activeFocus, "initial focus moves to first popover control")
            keyClick(Qt.Key_Tab)
            verify(popTog.activeFocus, "Tab moves inside the popover")
            keyClick(Qt.Key_Escape)
            tryCompare(pop, "opened", false)
            wait(450)
            verify(trigger.activeFocus, "Escape returns focus to the trigger")

            keyClick(Qt.Key_Space)
            tryCompare(pop, "opened", true)
            wait(200)
            verify(popBtn.activeFocus, "reopen focuses first control again")
            keyClick(Qt.Key_Space)
            tryCompare(pop, "opened", false)
            wait(450)
            verify(trigger.activeFocus, "closing from inside returns focus to the trigger")
        }

        function test_reduced_motion_inheritance() {
            Theme.stubReducedMotion = false
            Theme.stubAnimScale = 1
            compare(Theme.motionDuration(120), 120)
            Theme.stubAnimScale = 0.5
            compare(Theme.motionDuration(120), 60, "host animation scale applies")
            Theme.stubReducedMotion = true
            compare(Theme.motionDuration(120), 0, "reduced motion zeroes durations")
            Theme.stubReducedMotion = false
            Theme.stubAnimScale = 1
        }
    }
}
