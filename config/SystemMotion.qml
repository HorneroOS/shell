pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// System reduced-motion preference: the desktop-wide GNOME interface key
// `org.gnome.desktop.interface enable-animations` (also honoured by GTK
// apps). Missing gsettings/schema simply leaves `reduced` false.
Singleton {
    id: root

    property bool reduced: false

    function _parse(text: string): void {
        const value = text.trim().split(/\s+/).pop();
        if (value === "false")
            root.reduced = true;
        else if (value === "true")
            root.reduced = false;
    }

    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "enable-animations"]
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }

    Process {
        running: true
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "enable-animations"]
        stdout: SplitParser {
            onRead: line => root._parse(line)
        }
    }
}
