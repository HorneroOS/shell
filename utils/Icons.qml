pragma Singleton

import qs.config
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    readonly property var weatherIcons: ({
            "0": "sun",
            "1": "sun",
            "2": "sun-low",
            "3": "cloud",
            "45": "cloud-fog",
            "48": "cloud-fog",
            "51": "cloud-rain",
            "53": "cloud-rain",
            "55": "cloud-rain",
            "56": "cloud-rain",
            "57": "cloud-rain",
            "61": "cloud-rain",
            "63": "cloud-rain",
            "65": "cloud-rain",
            "66": "cloud-rain",
            "67": "cloud-rain",
            "71": "cloud-snow",
            "73": "cloud-snow",
            "75": "snowflake",
            "77": "cloud-snow",
            "80": "cloud-rain",
            "81": "cloud-rain",
            "82": "cloud-rain",
            "85": "cloud-snow",
            "86": "snowflake",
            "95": "cloud-storm",
            "96": "cloud-storm",
            "99": "cloud-storm"
        })

    readonly property var categoryIcons: ({
            WebBrowser: "world",
            Printing: "printer",
            Security: "shield-lock",
            Network: "message",
            Archiving: "archive",
            Compression: "archive",
            Development: "code",
            IDE: "code",
            TextEditor: "pencil",
            Audio: "music",
            Music: "music",
            Player: "music",
            Recorder: "microphone",
            Game: "device-gamepad-2",
            FileTools: "files",
            FileManager: "files",
            Filesystem: "files",
            FileTransfer: "files",
            Settings: "settings",
            DesktopSettings: "settings",
            HardwareSettings: "settings",
            TerminalEmulator: "terminal",
            ConsoleOnly: "terminal",
            Utility: "tool",
            Monitor: "heart-rate-monitor",
            Midi: "wave-sine",
            Mixer: "wave-sine",
            AudioVideoEditing: "video",
            AudioVideo: "video",
            Video: "video",
            Building: "barrier-block",
            Graphics: "photo",
            "2DGraphics": "photo",
            RasterGraphics: "photo",
            TV: "device-tv",
            System: "server-2",
            Office: "clipboard"
        })

    function getAppIcon(name: string, fallback: string): string {
        const icon = DesktopEntries.heuristicLookup(name)?.icon;
        if (fallback !== "undefined")
            return Quickshell.iconPath(icon, fallback);
        return Quickshell.iconPath(icon);
    }

    function getAppCategoryIcon(name: string, fallback: string): string {
        const categories = DesktopEntries.heuristicLookup(name)?.categories;

        if (categories)
            for (const [key, value] of Object.entries(categoryIcons))
                if (categories.includes(key))
                    return value;
        return fallback;
    }

    function getNetworkIcon(strength: int, isSecure = false): string {
        if (isSecure) {
            if (strength >= 80)
                return "wifi";
            if (strength >= 60)
                return "wifi-2";
            if (strength >= 40)
                return "wifi-1";
            if (strength >= 20)
                return "wifi-0";
            return "wifi-0";
        } else {
            if (strength >= 80)
                return "wifi";
            if (strength >= 60)
                return "wifi-2";
            if (strength >= 40)
                return "wifi-1";
            if (strength >= 20)
                return "wifi-0";
            return "wifi-0";
        }
    }

    function getBluetoothIcon(icon: string): string {
        if (icon.includes("headset") || icon.includes("headphones"))
            return "headphones";
        if (icon.includes("audio"))
            return "device-speaker";
        if (icon.includes("phone"))
            return "device-mobile";
        if (icon.includes("mouse"))
            return "mouse";
        if (icon.includes("keyboard"))
            return "keyboard";
        return "bluetooth";
    }

    function getWeatherIcon(code: string): string {
        if (weatherIcons.hasOwnProperty(code))
            return weatherIcons[code];
        return "wind";
    }

    function getNotifIcon(summary: string, urgency: int): string {
        summary = summary.toLowerCase();
        if (summary.includes("reboot"))
            return "reload";
        if (summary.includes("recording"))
            return "video";
        if (summary.includes("battery"))
            return "power";
        if (summary.includes("screenshot"))
            return "screenshot";
        if (summary.includes("welcome"))
            return "hand-stop";
        if (summary.includes("time") || summary.includes("a break"))
            return "clock";
        if (summary.includes("installed"))
            return "download";
        if (summary.includes("update"))
            return "clock-up";
        if (summary.includes("unable to"))
            return "package-off";
        if (summary.includes("profile"))
            return "user";
        if (summary.includes("file"))
            return "folders";
        if (urgency === NotificationUrgency.Critical)
            return "alert-octagon";
        return "message";
    }

    function getVolumeIcon(volume: real, isMuted: bool): string {
        if (isMuted)
            return "volume-3";
        if (volume >= 0.5)
            return "volume";
        if (volume > 0)
            return "volume-2";
        return "volume-3";
    }

    function getMicVolumeIcon(volume: real, isMuted: bool): string {
        if (!isMuted && volume > 0)
            return "microphone";
        return "microphone-off";
    }

    function getSpecialWsIcon(name: string): string {
        name = name.toLowerCase().slice("special:".length);

        for (const iconConfig of Config.bar.workspaces.specialWorkspaceIcons) {
            if (iconConfig.name === name) {
                return iconConfig.icon;
            }
        }

        if (name === "special")
            return "star";
        if (name === "communication")
            return "messages";
        if (name === "music")
            return "cast";
        if (name === "todo")
            return "checklist";
        if (name === "sysmon")
            return "heart-rate-monitor";
        return name[0].toUpperCase();
    }

    function getTrayIcon(id: string, icon: string): string {
        for (const sub of Config.bar.tray.iconSubs)
            if (sub.id === id)
                return sub.image ? Qt.resolvedUrl(sub.image) : Quickshell.iconPath(sub.icon);

        if (icon.includes("?path=")) {
            const [name, path] = icon.split("?path=");
            icon = Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
        }

        // StatusNotifier icon coverage varies wildly between themes; an
        // unresolvable name renders as a broken checkerboard placeholder.
        // Give IconImage an explicit fallback so it always paints something.
        if (!icon || icon === "")
            return "";
        if (icon.startsWith("file:"))
            return icon;
        return icon.includes("?fallback=") ? icon : `${icon}?fallback=image-missing`;
    }
}
