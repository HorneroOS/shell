pragma Singleton

import qs.services
import QtQuick

// Internal: the host's current experience mode (RFC 0001 §5a) as seen by
// PluginKit. The shell's experience service is the single owner of the
// mode; this bridge only reads it so Theme, Telemetry and the widget host
// agree on one value. Until a mode service reports otherwise the host is
// in `everyday`, except that an active GameMode is `gaming`.
QtObject {
    readonly property string mode: GameMode.enabled ? "gaming" : "everyday"
}
