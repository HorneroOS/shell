import QtQuick

// Launcher surface (shell#250 follow-up): the established
// query/result contract hosted by PluginLauncherHost. The host
// sets `query` (the text after ">example-multi-surface ") and
// reads `result`; an ok result becomes one launcher row whose
// activation copies its text (wl-copy, the calc convention).
Item {
    property string query: ""
    readonly property var result: query.trim() === "" ? {
        "ok": false,
        "text": ""
    } : {
        "ok": true,
        "text": query.trim().toUpperCase()
    }
}
