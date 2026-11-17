import QtQuick

Item {
    property string query: ""
    readonly property var result: ({ok: true, text: query})
}
