import QtQuick
import Hornero.PluginKit

Item {
    id: root

    // Host context (#372): declaring these properties opts in to the
    // host injecting the real surface values; the defaults keep the
    // plugin working on hosts without host context. On a vertical
    // rail or narrow bar (hostCompact) the weekday is dropped so the
    // label fits the rail instead of being clipped.
    property string hostOrientation: "horizontal"
    property bool hostCompact: false

    implicitWidth: label.implicitWidth + Theme.spacingSmall * 2
    implicitHeight: label.implicitHeight

    Settings {
        id: pluginSettings
        pluginId: "example-clock"
    }

    // Translations (#375): source strings are English; the Spanish
    // catalog ships at translations/es.json and loads automatically
    // when the shell (system) locale is Spanish. Any other locale
    // shows the English source strings.
    Translations {
        id: i18n
        pluginId: "example-clock"
    }

    // Keyboard contract (#376): the clock is an action (it posts a
    // toast), so it is a real UiButton — tab stop, Enter/Space
    // activation, visible focus and an accessible name/description
    // come from PluginKit instead of a mouse-only MouseArea.
    // formatDateTime uses the resolved locale, so weekday names
    // follow the same language as the translated strings.
    UiButton {
        id: label
        anchors.centerIn: parent
        variant: "ghost"
        text: i18n.formatDateTime(new Date(), pluginSettings.value("twentyFourHour", true) ? (root.hostCompact ? "HH:mm" : "ddd, HH:mm") : (root.hostCompact ? "h:mm ap" : "ddd, h:mm ap"))
        tooltipText: i18n.tr("Example Clock: activate for details")
        onClicked: Notifications.toast(i18n.tr("Example Clock"), i18n.tr("This example uses the public PluginKit API.") + " " + i18n.tr("Today is %1").arg(i18n.formatDateTime(new Date(), "dddd, d MMMM")), "schedule")
    }
}
