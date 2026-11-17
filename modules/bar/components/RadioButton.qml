import qs.components
import qs.components.controls
import qs.modules.companion
import qs.services
import qs.config
import QtQuick

// Javi Radio bar item: a small feather that opens the quick assistant.
// Optional (not in any shipped layout; add it in Control Center, Layout) and
// hidden when Radio or its bar entry is switched off in Javi settings.
// Opening is the whole action: the question and every approval happen in
// the Radio panel and the Workbench.
Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    property bool vertical
    readonly property bool shown: JaviRadio.enabled && CompanionStore.radioSettings.showInBar && CompanionStore.radioSettings.entryPoints.bar

    visible: root.shown
    implicitWidth: root.shown ? glyph.implicitWidth + Appearance.padding.small * 2 : 0
    implicitHeight: root.shown ? Math.max(glyph.implicitHeight, Density.inner - Appearance.padding.small * 2) : 0

    Accessible.role: Accessible.Button
    Accessible.name: JaviVoice.line("radio.title")
    Accessible.description: JaviVoice.line("radio.hint")

    Interactive {
        radius: Appearance.rounding.small
        Accessible.role: Accessible.Button
        Accessible.name: root.Accessible.name
        onClicked: JaviRadio.toggleFrom("bar")
    }

    Tooltip {
        target: root
        text: JaviVoice.line("radio.title")
    }

    Glyph {
        id: glyph

        anchors.centerIn: parent
        name: "feather"
        // Lit only while a real question is in flight.
        color: JaviRadio.busy ? root.tone.signal : root.tone.ink
        font.pointSize: Density.iconPt
    }
}
