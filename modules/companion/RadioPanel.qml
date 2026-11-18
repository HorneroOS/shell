pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.components.misc
import qs.modules.companion
import qs.services
import qs.config
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Javi Radio surface: a compact quick-question panel (a little transceiver:
// status lamp, one input line, one short answer) shown on the focused
// monitor only while JaviRadio.open. It is created on open and destroyed on
// close, so a closed Radio costs nothing. Keyboard first: Enter asks,
// Escape stops a question in flight or closes. It never shows tool
// activity, approvals or attachments; anything beyond a quick answer is a
// clear, user-initiated hand-off to the Workbench.
//
// Keyboard: an in-shell gesture opens it with on-demand focus (Hyprland:
// plus a focus grab, so clicking any other window takes the keyboard back
// and closes an idle Radio); an IPC open has no keyboard until the user
// clicks the panel. It never holds the keyboard exclusively on Hyprland.
Scope {
    id: root

    // Entry point: the global shortcut. The default binding is a hint
    // (Control Center shows it); the compositor config binds the name. This
    // is the trusted keyboard path: the compositor delivers it, no other
    // process can.
    CustomShortcut {
        name: "javiRadio"
        description: "Toggle Javi Radio"
        onPressed: JaviRadio.toggleFrom("shortcut")
    }

    // IPC (`qs ipc call javiradio ...`): any local process can call it, so
    // every call is the untrusted class (radio.js ipcEntry): "plugin", or
    // the opt-in "keybind" entry for compositor key bindings, which is just
    // as forgeable and documented so. Refused in Focus, Gaming and under
    // fullscreen; "plugin" opens without the keyboard. No call can submit a
    // question, approve, attach, run anything or change a setting; prefill
    // only places text in the input for the user to read and send.
    IpcHandler {
        target: "javiradio"

        function open(): string {
            return JaviRadio.openFromIpc("plugin") ? "opened" : "refused";
        }

        function toggle(): string {
            if (JaviRadio.open) {
                JaviRadio.close();
                return "ok";
            }
            return JaviRadio.openFromIpc("plugin") ? "ok" : "refused";
        }

        function openFrom(entry: string): string {
            return JaviRadio.openFromIpc((entry ?? "").toString()) ? "opened" : "refused";
        }

        function prefill(entry: string, text: string): string {
            return JaviRadio.prefill((entry ?? "").toString(), (text ?? "").toString()) ? "prefilled" : "refused";
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
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            // Top layer (a fullscreen window covers it), and Radio refuses
            // to open under fullscreen in the first place. Keyboard per
            // radio.js focusMode: none without a grant, on-demand with one
            // (exclusive only on niri, and only until a question finishes).
            WlrLayershell.keyboardFocus: JaviRadio.focusMode === "exclusive" ? WlrKeyboardFocus.Exclusive : JaviRadio.focusMode === "ondemand" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // Clicking another window ends the grab: the keyboard goes back
            // and an idle Radio closes (JaviRadio.focusLost).
            HyprlandFocusGrab {
                active: Compositor.isHyprland && JaviRadio.open && JaviRadio.keyboard
                windows: [win]
                onCleared: JaviRadio.focusLost()
            }

            anchors.bottom: true
            margins.bottom: Math.round((win.chosen?.height ?? 800) * 0.14)
            implicitWidth: 520
            implicitHeight: card.implicitHeight

            // Only the card takes input; the rest of the surface is empty.
            mask: Region {
                item: card
            }

            // Always-enabled key handler: Escape works while the input is
            // read-only (asking) and when focus sits on a button.
            FocusScope {
                id: keys

                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: event => {
                    JaviRadio.pressEscape();
                    event.accepted = true;
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

                    // A click on the panel is the user's gesture: it may take
                    // the keyboard (an IPC open starts without it).
                    TapHandler {
                        onTapped: {
                            JaviRadio.claimKeyboard();
                            input.forceActiveFocus();
                        }
                    }

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
                                radius: width / 2
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
                            // Read-only (not disabled) while asking, so it keeps
                            // focus and Escape still reaches the key handler.
                            readOnly: JaviRadio.busy
                            Accessible.name: JaviVoice.line("radio.placeholder")
                            Component.onCompleted: {
                                input.text = JaviRadio.draft;
                                input.forceActiveFocus();
                            }
                            // A click into the field claims the keyboard too
                            // (the field takes the press, so the card's
                            // handler would not see it).
                            TapHandler {
                                onTapped: JaviRadio.claimKeyboard()
                            }

                            // Enter is the only way a question is sent.
                            onAccepted: {
                                if (JaviRadio.busy)
                                    return;
                                JaviRadio.ask(input.text);
                                input.text = "";
                            }

                            Connections {
                                target: JaviRadio

                                function onDraftChanged(): void {
                                    if (JaviRadio.draft !== "")
                                        input.text = JaviRadio.draft;
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: !JaviRadio.keyboard
                            text: JaviVoice.line("radio.clickToType")
                            wrapMode: Text.Wrap
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkFaint
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

                        StyledText {
                            Layout.fillWidth: true
                            visible: JaviRadio.outcome === "superseded"
                            text: JaviVoice.line("radio.superseded")
                            wrapMode: Text.Wrap
                            color: Signal.palette.inkMuted
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
                                text: JaviVoice.line("radio.workbench")
                                type: TextButton.Filled
                                onClicked: JaviRadio.openWorkbench()
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                visible: JaviRadio.busy
                                text: JaviVoice.line("radio.stop")
                                type: TextButton.Tonal
                                onClicked: JaviRadio.cancel()
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            TextButton {
                                text: JaviVoice.line("radio.close")
                                type: TextButton.Text
                                onClicked: JaviRadio.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
