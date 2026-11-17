pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.misc
import qs.modules.companion
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Javi Radio surface: a compact quick-question panel (a little transceiver:
// status lamp, one input line, one short answer) shown on the focused
// monitor only while JaviRadio.open. It is created on open and destroyed on
// close, so a closed Radio costs nothing. Keyboard first: Enter asks,
// Escape closes (or stops a question in flight). It never shows tool
// activity, approvals or attachments; anything beyond a quick answer is a
// clear, user-initiated hand-off to the Workbench.
Scope {
    id: root

    // Entry point: the global shortcut. The default binding is a hint
    // (Control Center shows it); the compositor config binds the name.
    CustomShortcut {
        name: "javiRadio"
        description: "Toggle Javi Radio"
        onPressed: JaviRadio.toggleFrom("shortcut")
    }

    // Entry points for the launcher action, key bindings on other
    // compositors and extension commands. Every call only OPENS the radio
    // (and may submit one quick, read-only question); none can approve,
    // attach, run an agent or change a setting. An unknown or disabled
    // entry is refused.
    IpcHandler {
        target: "javiradio"

        function open(): string {
            return JaviRadio.openFrom("shortcut") ? "opened" : "refused";
        }

        function toggle(): string {
            return JaviRadio.toggleFrom("shortcut") ? "ok" : "refused";
        }

        function openFrom(entry: string): string {
            return JaviRadio.openFrom((entry ?? "").toString()) ? "opened" : "refused";
        }

        function ask(entry: string, text: string): string {
            if (!JaviRadio.open && !JaviRadio.openFrom((entry ?? "").toString()))
                return "refused";
            JaviRadio.ask((text ?? "").toString());
            return "asked";
        }

        function close(): void {
            JaviRadio.close();
        }

        function status(): string {
            return JSON.stringify({
                "enabled": JaviRadio.enabled,
                "open": JaviRadio.open,
                "outcome": JaviRadio.outcome,
                "entry": JaviRadio.entry
            });
        }
    }

    LazyLoader {
        active: JaviRadio.open

        PanelWindow {
            id: win

            readonly property string wantedScreen: Compositor.focusedOutputName
            readonly property var chosen: Quickshell.screens.find(s => s.name === win.wantedScreen) ?? Quickshell.screens[0]

            screen: win.chosen
            color: "transparent"
            WlrLayershell.namespace: "hornero-radio"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            // Explicit user gesture opened it: it may take the keyboard.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors.bottom: true
            margins.bottom: Math.round((win.chosen?.height ?? 800) * 0.14)
            implicitWidth: 520
            implicitHeight: card.implicitHeight

            // Only the card takes input; the rest of the surface is empty.
            mask: Region {
                item: card
            }

            StyledRect {
                id: card

                width: parent.width
                implicitHeight: col.implicitHeight + Appearance.padding.larger * 2
                radius: Appearance.rounding.normal
                color: Signal.palette.panel
                border.width: 1
                border.color: Signal.palette.rule

                Accessible.role: Accessible.Dialog
                Accessible.name: JaviVoice.line("radio.title")

                ColumnLayout {
                    id: col

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Appearance.padding.larger
                    spacing: Appearance.spacing.normal

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        // Status lamp: the real run state, nothing else.
                        Rectangle {
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: 4
                            color: JaviRadio.outcome === "failed" ? Signal.palette.alert : JaviRadio.outcome === "handoff" ? Signal.palette.cue : JaviRadio.busy ? Signal.palette.signal : Signal.palette.phosphor
                            Accessible.ignored: true
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: JaviVoice.line("radio.title")
                            mono: true
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.inkMuted
                        }

                        StyledText {
                            text: JaviRadio.busy ? JaviVoice.line("radio.busy") : ""
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.inkMuted
                        }
                    }

                    StyledTextField {
                        id: input

                        Layout.fillWidth: true
                        placeholderText: JaviVoice.line("radio.placeholder")
                        enabled: !JaviRadio.busy
                        onEnabledChanged: {
                            if (input.enabled)
                                input.forceActiveFocus();
                        }
                        Accessible.name: JaviVoice.line("radio.placeholder")
                        Component.onCompleted: input.forceActiveFocus()
                        onAccepted: {
                            JaviRadio.ask(input.text);
                            input.text = "";
                        }
                        Keys.onEscapePressed: JaviRadio.close()
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: JaviRadio.outcome === "idle"
                        text: JaviVoice.line("radio.hint")
                        wrapMode: Text.Wrap
                        font.pointSize: Appearance.font.size.smaller
                        color: Signal.palette.inkFaint
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: JaviRadio.question !== ""
                        text: JaviRadio.question
                        elide: Text.ElideRight
                        font.pointSize: Appearance.font.size.smaller
                        color: Signal.palette.inkMuted
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.maximumHeight: 240
                        visible: JaviRadio.outcome === "answer"
                        text: JaviRadio.answer
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        font.pointSize: Appearance.font.size.normal
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: JaviRadio.outcome === "failed"
                        text: JaviVoice.line("radio.unavailable")
                        wrapMode: Text.Wrap
                        color: Signal.palette.alert
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: JaviRadio.outcome === "handoff"
                        spacing: Appearance.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: JaviVoice.line("radio.handoff")
                            wrapMode: Text.Wrap
                            color: Signal.palette.cue
                        }

                        TextButton {
                            text: qsTr("Open the Workbench")
                            type: TextButton.Filled
                            onClicked: JaviRadio.openWorkbench()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        TextButton {
                            visible: JaviRadio.busy
                            text: qsTr("Stop")
                            type: TextButton.Tonal
                            onClicked: JaviRadio.cancel()
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        TextButton {
                            text: qsTr("Close")
                            type: TextButton.Text
                            onClicked: JaviRadio.close()
                        }
                    }
                }
            }
        }
    }
}
