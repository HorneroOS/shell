import QtQuick

Item {
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        text: Qt.formatDateTime(new Date(), "ddd, HH:mm")
    }
}
