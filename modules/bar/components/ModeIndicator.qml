import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Compact experience-mode indicator (shell#478, RFC 0001 §5a). Shows the
// active mode's glyph and, at `values`/`labels` density, a three-letter
// eyebrow. It is quiet by default: hidden in the factory mode (Everyday)
// and shown whenever another mode is active, so a person always sees
// that Focus, Signal, Gaming or Studio is on. `options.always` keeps it
// visible in Everyday too. Click opens Settings.
Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    property bool vertical
    property var options: ({})
    readonly property bool always: options?.always === true
    readonly property bool shown: always || Experience.mode !== "everyday"
    // Eyebrow codes: at most four characters (§4.1 labels).
    readonly property var codes: ({
            "focus": "FOC",
            "everyday": "EVR",
            "signal": "SIG",
            "gaming": "GAM",
            "studio": "STU"
        })
    readonly property string code: root.codes[Experience.mode] ?? ""
    readonly property bool showCode: !root.vertical && Experience.density !== "icons"
    // Non-default modes read in `signal`; Everyday stays muted.
    readonly property color accent: Experience.mode === "everyday" ? root.tone.inkMuted : root.tone.signal

    visible: root.shown
    implicitWidth: root.shown ? layout.implicitWidth + Appearance.padding.small * 2 : 0
    implicitHeight: root.shown ? Math.max(layout.implicitHeight, Density.inner - Appearance.padding.small * 2) : 0

    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Experience mode: %1").arg(Experience.label)
    Accessible.description: qsTr("Opens Settings")

    Interactive {
        id: interaction

        radius: Appearance.rounding.small
        Accessible.role: Accessible.Button
        Accessible.name: root.Accessible.name
        onClicked: ShellActions.run("settings")
    }

    Tooltip {
        target: root
        text: `${Experience.label} — ${Experience.profile.description}`
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        Glyph {
            name: Experience.glyph
            color: root.accent
            font.pointSize: Density.iconPt
        }

        StyledText {
            visible: root.showCode
            text: root.code
            color: root.accent
            font.family: Appearance.font.family.mono
            font.pointSize: Density.microPt
            font.weight: root.tone.weight > Font.Normal ? root.tone.weight : Font.Medium
            font.letterSpacing: 0.8
        }
    }
}
