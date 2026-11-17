pragma ComponentBehavior: Bound

import "../../components"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import "../../../../services/chromatic.js" as Colour

// Source of the palette (RFC 0002 §7): wallpaper, an image file, a single
// accent colour, or the plain Signal house palette; ranked seed chips from
// the analysis; a manual accent picker (hue and chroma, or a hex code).
ColumnLayout {
    id: root

    // Working request (services/chromaticcli.js normalise()).
    required property var request
    // Ranked seeds from the analysis: [{hex, share}]
    property var seeds: []
    property string wallpaper: ""

    signal sourceChosen(string kind, var value)
    signal seedChosen(string hex)

    readonly property var kinds: ["wallpaper", "image", "seed", "house"]
    readonly property var kindLabels: [qsTr("Wallpaper"), qsTr("Image"), qsTr("Colour"), qsTr("Signal house")]
    readonly property string accent: root.request.seeds.length > 0 ? root.request.seeds[0] : "#D98A3A"
    readonly property var accentHc: Colour.hexToHueChroma(root.accent)

    spacing: Appearance.spacing.small

    SegmentedControl {
        accessibleName: qsTr("Palette source")
        model: root.kindLabels
        currentIndex: Math.max(0, root.kinds.indexOf(root.request.source))
        onActivated: index => root.sourceChosen(root.kinds[index], index === 1 ? root.request.path : index === 2 ? [root.accent] : "")
    }

    StyledText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        text: {
            switch (root.request.source) {
            case "wallpaper":
                return root.wallpaper ? qsTr("Follows your current wallpaper: %1").arg(root.wallpaper.split("/").pop()) : qsTr("No wallpaper is set. Choose one in Background, or pick another source.");
            case "image":
                return qsTr("Builds the palette from an image file. The image is only read, never changed.");
            case "seed":
                return qsTr("Builds the palette around one accent colour of your choice.");
            default:
                return qsTr("The plain Signal palette, optionally tinted by the wallpaper. No image analysis.");
            }
        }
    }

    RowLayout {
        visible: root.request.source === "image"
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledTextField {
            id: pathField

            Layout.fillWidth: true
            placeholderText: qsTr("/path/to/image.jpg")
            text: root.request.path
            Accessible.name: qsTr("Image path")
            onAccepted: root.sourceChosen("image", text.trim())
        }

        TextButton {
            text: qsTr("Use")
            type: TextButton.Tonal
            onClicked: root.sourceChosen("image", pathField.text.trim())
        }
    }

    // Ranked seeds: the colours the engine found, strongest first.
    ColumnLayout {
        visible: root.seeds.length > 0 && (root.request.source === "wallpaper" || root.request.source === "image")
        Layout.fillWidth: true
        spacing: 2

        Eyebrow {
            label: qsTr("Colours found in the image")
        }

        Flow {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            Repeater {
                model: root.seeds

                StyledRect {
                    id: seedChip

                    required property var modelData
                    required property int index

                    implicitWidth: seedRow.implicitWidth + Appearance.padding.normal * 2
                    implicitHeight: seedRow.implicitHeight + Appearance.padding.small * 2
                    radius: Appearance.rounding.small
                    color: Signal.layer(Signal.palette.raised, 1)
                    border.width: 1
                    border.color: activeFocus ? Signal.palette.focus : Signal.palette.rule
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Use %1 as the accent, found %2 of the image").arg(modelData.hex).arg(Math.round((modelData.share ?? 0) * 100) + "%")
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
                            root.seedChosen(modelData.hex);
                            event.accepted = true;
                        }
                    }

                    Row {
                        id: seedRow

                        anchors.centerIn: parent
                        spacing: Appearance.spacing.small

                        Rectangle {
                            width: 14
                            height: 14
                            color: seedChip.modelData.hex
                            border.width: 1
                            border.color: Signal.palette.ruleStrong
                        }

                        StyledText {
                            mono: true
                            text: `${seedChip.index + 1}  ${seedChip.modelData.hex}`
                            font.pointSize: Appearance.font.size.smaller
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.seedChosen(seedChip.modelData.hex)
                    }
                }
            }
        }
    }

    // Manual accent picker.
    ColumnLayout {
        visible: root.request.source === "seed"
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            Rectangle {
                width: 36
                height: 36
                color: root.accent
                border.width: 1
                border.color: Signal.palette.ruleStrong
                Accessible.role: Accessible.Graphic
                Accessible.name: qsTr("Accent preview %1").arg(root.accent)
            }

            StyledTextField {
                id: hexField

                Layout.preferredWidth: 110
                text: root.accent
                maximumLength: 7
                validator: RegularExpressionValidator {
                    regularExpression: /^#[0-9A-Fa-f]{0,6}$/
                }
                Accessible.name: qsTr("Accent colour hex code")
                onAccepted: {
                    if (/^#[0-9A-Fa-f]{6}$/.test(text))
                        root.seedChosen(text.toUpperCase());
                }
            }
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Accent hue")
            value: root.accentHc.hue
            from: 0
            to: 359
            suffix: "°"
            validator: IntValidator {
                bottom: 0
                top: 359
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)
            onValueModified: v => root.seedChosen(Colour.oklchHex(0.7, Math.max(0.05, root.accentHc.chroma), v))
        }

        SliderInput {
            Layout.fillWidth: true
            label: qsTr("Accent intensity")
            value: Math.min(25, Math.max(4, root.accentHc.chroma * 100))
            from: 4
            to: 25
            suffix: ""
            validator: IntValidator {
                bottom: 4
                top: 25
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)
            onValueModified: v => root.seedChosen(Colour.oklchHex(0.7, v / 100, root.accentHc.hue))
        }
    }
}
