pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.services
import qs.config
import QtQuick

Item {
    id: root

    property string text: ""
    property var validator: null
    property bool readOnly: false
    property int horizontalAlignment: TextInput.AlignHCenter
    property int implicitWidth: 70
    property bool enabled: true

    // Expose activeFocus through alias to avoid FINAL property override
    readonly property alias hasFocus: inputField.activeFocus

    signal textEdited(string text)
    signal editingFinished
    // Enter/Return only. editingFinished also fires on focus loss, so
    // anything that sends or submits must use accepted.
    signal accepted

    // Focus the inner text field (focusing the wrapper Item alone
    // leaves typing with nowhere to go).
    function focusInput(): void {
        inputField.forceActiveFocus();
    }

    // Replace the visible text even while the field has focus (the
    // `text` binding only follows while it does not), so what is shown
    // is always what would be sent.
    function replaceText(value: string): void {
        inputField.text = value;
        root.text = value;
    }

    implicitHeight: inputField.implicitHeight + Appearance.padding.small * 2

    StyledRect {
        id: container

        anchors.fill: parent
        // Sunken readout well (signal-visual-language §4.1): values a person
        // types live in an inset, never on a raised card.
        color: inputHover.containsMouse && !inputField.activeFocus ? Signal.layer(Signal.palette.sunken, 2) : Signal.palette.sunken
        radius: Appearance.rounding.small
        border.width: 1
        border.color: inputField.activeFocus ? Signal.palette.focus : Signal.palette.rule
        opacity: root.enabled ? 1 : 0.5

        Behavior on color {
            CAnim {}
        }
        Behavior on border.color {
            CAnim {}
        }

        MouseArea {
            id: inputHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.IBeamCursor
            acceptedButtons: Qt.NoButton
            enabled: root.enabled
        }

        StyledTextField {
            id: inputField
            anchors.centerIn: parent
            width: parent.width - Appearance.padding.normal
            horizontalAlignment: root.horizontalAlignment
            validator: root.validator
            readOnly: root.readOnly
            enabled: root.enabled

            Binding {
                target: inputField
                property: "text"
                value: root.text
                when: !inputField.activeFocus
            }

            onTextChanged: {
                root.text = text;
                root.textEdited(text);
            }

            onEditingFinished: {
                root.editingFinished();
            }

            onAccepted: root.accepted()
        }
    }
}
