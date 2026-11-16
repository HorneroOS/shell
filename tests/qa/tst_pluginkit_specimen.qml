// PluginKit 3 offscreen specimen (tests/test_pluginkit_signal.py). Renders
// every Signal component with FIXED FIXTURE DATA (not telemetry) and saves
// a PNG when SPECIMEN_OUT is set, so reviewers can inspect the kit without
// a live shell. Also asserts the real-data rules: unavailable instruments
// render an em dash and no trace.
import QtQuick
import QtTest
import Hornero.PluginKit

Rectangle {
    id: page

    width: 1120
    height: 640
    color: Theme.palette.ground

    // Deterministic fixture series (sum of two sines), NOT telemetry.
    function series(n, phase, scale) {
        const out = [];
        for (let i = 0; i < n; i++)
            out.push(0.42 + scale * (0.22 * Math.sin((i + phase) / 6) + 0.12 * Math.sin((i + phase) / 2.3)));
        return out;
    }

    Row {
        x: 24
        y: 24
        spacing: 24

        UiCard {
            id: telemetry

            width: 560
            height: 392
            channel: 2
            title: "Telemetry"
            context: "fixture · 60 s window"

            Column {
                width: parent.width
                spacing: Theme.spacing.normal

                Row {
                    spacing: Theme.spacing.normal

                    UiScope {
                        id: scope

                        width: 360
                        height: 150
                        label: "CPU · 10 %/DIV"
                        context: "60 S"
                        samples: page.series(120, 120, 1)
                        previous: page.series(120, 0, 1)
                    }

                    Column {
                        spacing: Theme.spacing.smaller

                        UiMetric {
                            width: 162
                            label: "CPU"
                            value: "34"
                            unit: "%"
                        }

                        UiMetric {
                            id: noTemp

                            width: 162
                            label: "Pkg temp"
                            value: "61"
                            unit: "°C"
                            available: false
                        }
                    }
                }

                UiMeterRow {
                    width: parent.width
                    label: "GPU"
                    value: 0.22
                    valueText: "22 %"
                }

                UiMeterRow {
                    width: parent.width
                    label: "Disk"
                    value: 0.91
                    valueText: "91 %"
                }

                UiMeterRow {
                    width: parent.width
                    label: "Fan"
                    available: false
                }

                Row {
                    spacing: Theme.spacing.normal

                    UiText {
                        role: "eyebrow"
                        text: "Mem"
                        width: 40
                    }

                    UiPartition {
                        width: 380
                        total: 32
                        used: 11.2
                        secondary: 6.1
                        usedLabel: "used"
                        secondaryLabel: "cache"
                    }

                    UiText {
                        role: "value"
                        text: "11.2 G"
                    }
                }

                Row {
                    spacing: Theme.spacing.normal

                    UiText {
                        role: "eyebrow"
                        text: "Net↓"
                        width: 40
                    }

                    UiSparkline {
                        width: 380
                        height: 20
                        tone: "cue"
                        values: page.series(60, 9, 0.8)
                    }

                    UiText {
                        role: "value"
                        text: "2.4 MB/s"
                    }
                }
            }
        }

        Column {
            spacing: Theme.spacing.normal

            UiCard {
                width: 460
                height: 220
                channel: 3
                title: "Controls"

                Column {
                    spacing: Theme.spacing.normal

                    Row {
                        spacing: Theme.spacing.smaller

                        UiButton {
                            variant: "primary"
                            text: "Start"
                            glyph: "player-play"
                        }

                        UiButton {
                            text: "Reset"
                            glyph: "refresh"
                        }

                        UiButton {
                            variant: "quiet"
                            text: "Skip"
                        }

                        UiButton {
                            variant: "danger"
                            text: "Clear"
                        }

                        UiButton {
                            text: "Off"
                            enabled: false
                        }
                    }

                    Row {
                        spacing: Theme.spacing.smaller

                        UiChip {
                            text: "neutral"
                        }

                        UiChip {
                            tone: "signal"
                            text: "selected"
                        }

                        UiChip {
                            tone: "cue"
                            text: "info"
                        }

                        UiChip {
                            tone: "phosphor"
                            text: "healthy"
                        }

                        UiChip {
                            tone: "alert"
                            text: "over"
                        }

                        UiChip {
                            tone: "live"
                            text: "rec"
                        }
                    }

                    Row {
                        spacing: Theme.spacing.large

                        UiToggle {
                            text: "Rocker on"
                            value: true
                        }

                        UiToggle {
                            text: "Off"
                        }
                    }

                    Row {
                        spacing: Theme.spacing.normal

                        UiSlider {
                            width: 220
                            value: 0.62
                            accessibleName: "Output"
                        }

                        UiText {
                            role: "value"
                            text: "62"
                        }
                    }
                }
            }

            UiCard {
                width: 460
                height: 196
                channel: 4
                title: "Rows"
                context: "popout"

                Column {
                    width: parent.width
                    spacing: 0

                    UiDetailRow {
                        width: parent.width
                        label: "Output"
                        value: "Line out"
                        glyph: "volume"
                    }

                    UiDetailRow {
                        width: parent.width
                        label: "Battery"
                        available: false
                    }

                    UiActionRow {
                        width: parent.width
                        text: "Built-in speakers"
                        glyph: "device-speaker"
                    }

                    UiActionRow {
                        width: parent.width
                        text: "Headphones"
                        glyph: "headphones"
                        selected: true
                    }
                }
            }
        }
    }

    Row {
        x: 24
        y: 440
        spacing: 24

        UiScope {
            id: deadScope

            width: 300
            height: 120
            label: "GPU · 10 %/DIV"
            available: false
            unavailableText: "No GPU load sensor"
        }

        Row {
            spacing: 12

            Repeater {
                model: 8

                UiSegmentMeter {
                    required property int index

                    orientation: "vertical"
                    count: 14
                    vu: true
                    value: [0.2, 0.55, 0.9, 0.35, 0.7, 0.15, 0.62, 0.48][index]
                    peak: [0.3, 0.6, 0.95, 0.4, 0.75, 0.2, 0.7, 0.5][index]
                }
            }
        }

        UiState {
            kind: "unavailable"
            message: "No battery on this machine"
        }
    }

    TestCase {
        name: "PluginKitSpecimen"
        when: windowShown

        function test_unavailable_instruments_show_no_value() {
            verify(!deadScope._hasTrace, "unavailable scope draws no trace");
            compare(noTemp._shown, false);
        }

        function test_glow_follows_experience() {
            console.log("glow", Theme.experience, Theme.glowEnabled, scope.glowing, scope._granted, scope._wantsGlow);
            compare(scope.glowing, Theme.glowEnabled, "scope glow follows the experience gate");
        }

        function test_save_specimen() {
            wait(400);
            const out = page.specimenPath;
            if (out.length === 0)
                skip("SPECIMEN_OUT not set");
            let saved = false;
            page.grabToImage(result => {
                saved = result.saveToFile(out);
            });
            tryVerify(() => saved, 5000, `saved ${out}`);
        }
    }

    property string specimenPath: ""
}
