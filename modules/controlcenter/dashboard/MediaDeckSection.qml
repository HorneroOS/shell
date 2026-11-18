import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Media deck on the dashboard home (docs/DASHBOARD.md "Media deck"): the
// stereo spectrum beside the cover well, its peak-hold ticks, the band
// count, and Javi dozing in the empty well. Every value persists in
// dashboard.media, previews live on the open dashboard and resets.
SectionContainer {
    id: root

    readonly property var media: Config.dashboard.media
    readonly property var factory: ({
            "spectrum": true,
            "peakHold": true,
            "bands": 12,
            "javi": true
        })

    function resetAll(): void {
        Undo.offerValues("media-deck-reset", qsTr("Media deck reset to factory"), [
            {
                "obj": Config.dashboard.media,
                "keys": Object.keys(root.factory)
            }
        ], qsTr("Undo brings back your spectrum, peak ticks, bands and Javi."));
        for (const k of Object.keys(root.factory))
            root.media[k] = root.factory[k];
        Config.save();
    }

    Layout.fillWidth: true
    alignTop: true

    Eyebrow {
        label: qsTr("Media deck")
        color: Signal.palette.ink
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("The deck on the dashboard home: the cover well with the left and right channels on either side, a tape counter and the transport. The spectrum only moves while something plays, and stays still when motion is off.")
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        wrapMode: Text.WordWrap
    }

    SwitchRow {
        label: qsTr("Stereo spectrum")
        checked: root.media.spectrum
        onToggled: checked => {
            root.media.spectrum = checked;
            Config.save();
        }
    }

    SwitchRow {
        label: qsTr("Peak-hold ticks")
        checked: root.media.peakHold
        enabled: root.media.spectrum
        onToggled: checked => {
            root.media.peakHold = checked;
            Config.save();
        }
    }

    SizeSlider {
        target: Config.dashboard.media
        key: "bands"
        label: qsTr("Bands per channel")
        from: 8
        to: 24
        defaultValue: 12
        suffix: ""
        enabled: root.media.spectrum
    }

    SwitchRow {
        label: qsTr("Javi dozes when nothing plays")
        checked: root.media.javi
        onToggled: checked => {
            root.media.javi = checked;
            Config.save();
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.media.javi && !Atmosphere.mascot
        text: qsTr("Javi is hidden because the mascot is off in Appearance, Atmosphere.")
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
        wrapMode: Text.WordWrap
    }

    TextButton {
        text: qsTr("Reset media deck to factory")
        type: TextButton.Tonal
        Accessible.name: qsTr("Reset every media deck setting to its factory value")
        onClicked: root.resetAll()
    }
}
