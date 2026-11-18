import ".."
import "../components"
import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Dashboard home composition (dashboard.composition). The open dashboard
// follows the choice live; Reset returns to "console".
SectionContainer {
    id: root

    Layout.fillWidth: true
    alignTop: true

    Eyebrow {
        label: qsTr("Layout")
        color: Signal.palette.ink
    }

    ChoiceRow {
        target: Config.dashboard
        key: "composition"
        label: qsTr("Home composition")
        defaultValue: "console"
        options: [
            {
                "id": "console",
                "label": qsTr("Console")
            },
            {
                "id": "classic",
                "label": qsTr("Classic")
            },
            {
                "id": "compact",
                "label": qsTr("Compact")
            }
        ]
    }

    StyledText {
        Layout.fillWidth: true
        text: Config.dashboard.composition === "classic" ? qsTr("An even grid: station, clock and weather on top, calendar and resources below, the media deck as a strip at the bottom.") : Config.dashboard.composition === "compact" ? qsTr("The even grid without the media deck, for a shorter dashboard.") : qsTr("A broadcast console: a wide clock with a seconds ruler, the media deck as the tall hero on the right, and a thin weather strip.")
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        wrapMode: Text.WordWrap
    }
}
