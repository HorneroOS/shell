pragma Singleton

import QtQuick

// Version marker of the installed PluginKit. The Shell host reads it to
// refuse extensions plainly when the resolved Hornero.PluginKit module is
// older than the Shell expects (a package upgrade that left the previous
// kit on the import path). Bump apiLevel together with schemaVersion in
// scripts/validate_plugin.py (SCHEMA_VERSIONS / PLUGINKIT_API_LEVEL).
QtObject {
    readonly property int apiLevel: 3
    readonly property string name: "PluginKit 3 (Hornero Signal)"
}
