import QtQuick

// Signal chip: a small labelled tag with radius 3 (never a pill).
//
//   tone: "neutral" (default) raised fill, inkMuted label, rule outline
//         "signal"   signalWell / onSignalWell — selected, primary
//         "cue"      cueWell / onCueWell — information
//         "phosphor" phosphorWell / onPhosphorWell — healthy, connected
//         "alert"    alertWell / onAlertWell — error, over threshold
//         "live"     on-air chip: signal fill, onSignal, Plex Mono
//                    SemiBold uppercase — only while something is truly
//                    live (recording, capturing, running)
Rectangle {
    id: root

    property string text: ""
    property string tone: "neutral"
    property string glyph: ""

    readonly property bool live: root.tone === "live"
    readonly property color inkColor: root.live ? Theme.palette.onSignal : root.tone === "signal" ? Theme.palette.onSignalWell : root.tone === "cue" ? Theme.palette.onCueWell : root.tone === "phosphor" ? Theme.palette.onPhosphorWell : root.tone === "alert" ? Theme.palette.onAlertWell : Theme.palette.inkMuted

    implicitWidth: row.implicitWidth + Theme.padding.smaller * 2
    implicitHeight: Math.max(18, row.implicitHeight + Theme.padding.small)
    radius: Theme.rounding.small
    color: root.live ? Theme.palette.signal : root.tone === "signal" ? Theme.palette.signalWell : root.tone === "cue" ? Theme.palette.cueWell : root.tone === "phosphor" ? Theme.palette.phosphorWell : root.tone === "alert" ? Theme.palette.alertWell : Theme.palette.raised
    border.width: root.tone === "neutral" ? 1 : 0
    border.color: Theme.palette.rule

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.spacing.small

        UiIcon {
            visible: root.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            name: root.glyph
            size: Theme.font.size.small
            color: root.inkColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.inkColor
            font.family: root.live ? Theme.font.family.mono : Theme.font.family.sans
            font.weight: root.live ? Font.DemiBold : Font.Normal
            font.capitalization: root.live ? Font.AllUppercase : Font.MixedCase
            font.pointSize: Theme.font.size.small
            font.features: ({
                    "tnum": 1
                })
        }
    }
}
