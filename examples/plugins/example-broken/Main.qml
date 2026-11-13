import QtQuick

// QA FIXTURE — deliberately broken. Do not "fix" the type below.
// This entrypoint is statically valid (allowed imports only, no
// forbidden patterns) so scripts/validate_plugin.py accepts the
// package and it can be installed/discovered like a healthy plugin.
// At runtime the QML engine cannot resolve BrokenFixtureMissingType,
// so the component fails to create, the PluginHost Loader reports
// Loader.Error, and services/Plugins.qml marks only this plugin
// failed (bounded, redacted diagnostic) while neighbours keep
// loading. That is the load-failure isolation qa#81 proves.
Item {
    BrokenFixtureMissingType {
    }
}
