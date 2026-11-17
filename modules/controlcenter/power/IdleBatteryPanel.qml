import "../components"
import qs.components
import qs.components.controls
import qs.config
import qs.services
import QtQuick
import QtQuick.Layouts

// Idle timeouts (lock, screen off, suspend) and battery warning levels.
// Values live in general.idle.timeouts and general.battery; each row has a
// Reset to the factory value. Minutes in the UI, seconds in the config.
ChannelPanel {
    id: root

    // Index of the timeout whose idleAction matches, or -1 if the user
    // removed it by hand-editing shell.json.
    function indexOfAction(kind: string): int {
        const list = Config.general.idle.timeouts;
        for (let i = 0; i < list.length; i++) {
            const a = list[i].idleAction;
            if (kind === "lock" && a === "lock")
                return i;
            if (kind === "dpms" && a === "dpms off")
                return i;
            if (kind === "suspend" && Array.isArray(a))
                return i;
        }
        return -1;
    }

    function timeoutMinutes(kind: string, fallback: real): real {
        const i = root.indexOfAction(kind);
        return i < 0 ? fallback : Config.general.idle.timeouts[i].timeout / 60;
    }

    function setTimeoutMinutes(kind: string, minutes: real): void {
        const i = root.indexOfAction(kind);
        if (i < 0)
            return;
        const list = Config.general.idle.timeouts.map(e => Object.assign({}, e));
        list[i].timeout = Math.round(minutes * 60);
        Config.general.idle.timeouts = list;
        Config.save();
    }

    function levelAt(rank: int, fallback: int): int {
        const sorted = [...Config.general.battery.warnLevels].sort((a, b) => b.level - a.level);
        return rank < sorted.length ? sorted[rank].level : fallback;
    }

    function setLevel(rank: int, value: int): void {
        const sorted = [...Config.general.battery.warnLevels].map(e => Object.assign({}, e)).sort((a, b) => b.level - a.level);
        if (rank >= sorted.length)
            return;
        sorted[rank].level = value;
        Config.general.battery.warnLevels = sorted;
        Config.save();
    }

    title: qsTr("Idle and battery")

    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: Appearance.padding.large
        spacing: Appearance.spacing.small

        component ThresholdRow: RowLayout {
            id: row

            required property string label
            required property real from
            required property real to
            required property real current
            required property real factory
            property string suffix: "min"
            signal committed(real value)

            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            SliderInput {
                Layout.fillWidth: true

                label: row.label
                value: row.current
                from: row.from
                to: row.to
                stepSize: 1
                suffix: row.suffix
                decimals: 0
                validator: IntValidator {
                    bottom: row.from
                    top: row.to
                }
                formatValueFunction: val => Math.round(val).toString()
                parseValueFunction: text => parseInt(text)
                onValueModified: val => row.committed(Math.max(row.from, Math.min(row.to, Math.round(val))))
            }

            TextButton {
                text: qsTr("Reset")
                type: TextButton.Text
                visible: Math.abs(row.current - row.factory) > 1e-9
                Accessible.name: qsTr("Reset %1 to default").arg(row.label)
                onClicked: row.committed(row.factory)
            }
        }

        ThresholdRow {
            label: qsTr("Lock after")
            from: 1
            to: 60
            current: root.timeoutMinutes("lock", 3)
            factory: 3
            onCommitted: v => root.setTimeoutMinutes("lock", v)
        }

        ThresholdRow {
            label: qsTr("Turn screen off after")
            from: 1
            to: 120
            current: root.timeoutMinutes("dpms", 5)
            factory: 5
            onCommitted: v => root.setTimeoutMinutes("dpms", v)
        }

        ThresholdRow {
            label: qsTr("Suspend after")
            from: 5
            to: 480
            current: root.timeoutMinutes("suspend", 10)
            factory: 10
            onCommitted: v => root.setTimeoutMinutes("suspend", v)
        }

        ThresholdRow {
            label: qsTr("Low battery warning at")
            suffix: "%"
            from: 10
            to: 50
            current: root.levelAt(0, 20)
            factory: 20
            onCommitted: v => root.setLevel(0, v)
        }

        ThresholdRow {
            label: qsTr("Second warning at")
            suffix: "%"
            from: 6
            to: 30
            current: root.levelAt(1, 10)
            factory: 10
            onCommitted: v => root.setLevel(1, v)
        }

        ThresholdRow {
            label: qsTr("Critical warning at")
            suffix: "%"
            from: 2
            to: 15
            current: root.levelAt(2, 5)
            factory: 5
            onCommitted: v => root.setLevel(2, v)
        }

        ThresholdRow {
            label: qsTr("Hibernate at")
            suffix: "%"
            from: 1
            to: 10
            current: Config.general.battery.criticalLevel
            factory: 3
            onCommitted: v => {
                Config.general.battery.criticalLevel = v;
                Config.save();
            }
        }
    }
}
