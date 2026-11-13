import QtQuick

// QA FIXTURE — deliberately broken. Do not "fix" the type below.
// Statically valid (allowed imports only), but the QML engine
// cannot resolve BrokenLauncherFixtureMissingType, so the
// PluginLauncherHost Loader reports Loader.Error and marks only
// this plugin failed while other launcher providers keep working.
Item {
    property string query: ""
    readonly property var result: {
        "ok": false,
        "text": ""
    }

    BrokenLauncherFixtureMissingType {
    }
}
