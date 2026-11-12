pragma Singleton

import qs.services as Services
import QtQuick

QtObject {
    readonly property date date: Services.Time.date
    readonly property int hours: Services.Time.hours
    readonly property int minutes: Services.Time.minutes
    readonly property int seconds: Services.Time.seconds
    readonly property string timeStr: Services.Time.timeStr

    function format(fmt: string): string {
        return Services.Time.format(fmt);
    }
}
