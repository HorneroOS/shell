import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Label on the left, value in Plex Mono on the right. Callers pass a real
// value or leave it empty: an empty value prints "unavailable", never a
// placeholder number.
RowLayout {
    id: root

    required property string label
    required property string value
    property bool showTopMargin: false
    // 0..1 real level (e.g. Wi-Fi signal); -1 shows no meter.
    property real level: -1

    spacing: Appearance.spacing.normal

    Accessible.role: Accessible.StaticText
    Accessible.name: `${root.label}: ${root.shown}`

    readonly property string shown: root.value.length > 0 ? root.value : qsTr("unavailable")

    StyledText {
        Layout.topMargin: root.showTopMargin ? Appearance.spacing.small : 0
        text: root.label
    }

    Item {
        Layout.fillWidth: true
    }

    SegmentMeter {
        visible: root.level >= 0 && root.value.length > 0
        Layout.topMargin: root.showTopMargin ? Appearance.spacing.small : 0
        count: 5
        segmentThickness: 6
        segmentLength: 10
        value: root.level
        available: root.level >= 0
        threshold: 1.1
        accessibleName: qsTr("%1 level").arg(root.label)
    }

    StyledText {
        Layout.topMargin: root.showTopMargin ? Appearance.spacing.small : 0
        Layout.minimumWidth: 0
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideMiddle
        mono: true
        text: root.shown
        color: root.value.length > 0 ? Signal.palette.ink : Signal.palette.inkMuted
        font.pointSize: Appearance.font.size.small
    }
}
