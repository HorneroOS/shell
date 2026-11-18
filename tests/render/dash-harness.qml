import QtQuick
import QtQuick.Window
import Quickshell
import qs.services
import qs.config
import qs.modules.dashboard

// Offscreen render of the dashboard home (Dash.qml) for the media deck and
// composition checks. env: HW HH (window), HOUT (png), DECK_PLAYER=1 for a
// scripted playing player. Prints DASHPROBE with frame geometry.
ShellRoot {
    id: root

    readonly property int sw: parseInt(Quickshell.env("HW"))
    readonly property int sh: parseInt(Quickshell.env("HH"))

    PersistentProperties {
        id: vis

        property bool dashboard: true
    }

    PersistentProperties {
        id: st

        property int currentTab: 0
        property date currentDate: new Date()
    }

    Window {
        visible: true
        width: root.sw
        height: root.sh
        color: Signal.palette.ground

        Item {
            id: stage

            anchors.fill: parent

            Rectangle {
                anchors.centerIn: dash
                width: dash.width + 32
                height: dash.height + 32
                color: Signal.palette.base
                radius: Appearance.rounding.small
            }

            Dash {
                id: dash

                anchors.centerIn: parent
                visibilities: vis
                state: st
                facePicker: null
            }
        }

        Timer {
            interval: 4000
            running: true
            onTriggered: {
                const frames = [];
                for (let i = 0; i < dash.children.length; i++) {
                    const c = dash.children[i];
                    if (c.visible && c.width > 0 && c.title !== undefined)
                        frames.push({ title: c.title, channel: c.channel, x: c.x, y: c.y, w: c.width, h: c.height });
                }
                console.log("DASHPROBE " + JSON.stringify({ w: dash.width, h: dash.height, frames: frames }));
                stage.grabToImage(r => {
                    r.saveToFile(Quickshell.env("HOUT"));
                    Qt.quit();
                });
            }
        }
    }
}
