import "components"
import QtQuick
import QtQuick.Window
import Quickshell

// Shader-effect interceptor harness: the real StateLayer (hover wash) and
// StyledClippingRect, created many times like the shell's list rows, with
// their colours changed so every Behavior is armed. The test fails on any
// "another interceptor" warning in the log.
ShellRoot {
    Window {
        visible: true
        width: 400
        height: 400
        color: "#10131a"

        Column {
            Repeater {
                model: 20

                Item {
                    id: row

                    required property int index

                    width: 200
                    height: 12

                    StyledClippingRect {
                        id: plain

                        anchors.fill: parent
                        radius: 4
                        color: row.index % 2 ? "#336699" : "transparent"
                    }

                    StateLayer {
                        radius: 4
                        showHoverBackground: row.index % 2 === 0
                    }
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: {
            console.log("SHADER-DONE");
            Qt.quit();
        }
    }
}
