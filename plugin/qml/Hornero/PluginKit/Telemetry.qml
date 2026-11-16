pragma Singleton

import qs.services as Services
import QtQuick

// Shared telemetry history for instruments (scopes, sparklines). One
// ring buffer per channel, filled from the shell services' own samples —
// PluginKit never polls on its own and never invents samples. A channel
// whose sensor is unavailable records nothing, so its window stays empty
// and instruments show "unavailable".
//
// Channels: "cpu" "gpu" "mem" (0–1), "cpuTemp" "gpuTemp" (°C),
// "netDown" "netUp" (bytes/s).
//
//   window("cpu")          the latest `windowSize` samples, oldest first
//   previousWindow("cpu")  the window before it (scope persistence)
//   latest("cpu")          newest sample, or NaN when none
//
// History only advances while a "system"/"network" lease is held
// (Subscription), at the shared cadence (1 Hz everyday, 2 Hz signal).
QtObject {
    id: root

    readonly property int windowSize: 120
    readonly property var channels: ["cpu", "gpu", "mem", "cpuTemp", "gpuTemp", "netDown", "netUp"]
    // Bumped on every sample; bindings that call window()/latest() read it.
    property int revision: 0

    property var _buffers: ({})
    property var _cost: ({})

    function _push(channel: string, value: real): void {
        if (!isFinite(value))
            return;
        let buf = root._buffers[channel];
        if (!buf) {
            buf = [];
            root._buffers[channel] = buf;
        }
        buf.push(value);
        if (buf.length > root.windowSize * 2)
            buf.splice(0, buf.length - root.windowSize * 2);
    }

    function _record(domain: string, started: real): void {
        const elapsed = Date.now() - started;
        const c = root._cost[domain] ?? {
            "samples": 0,
            "totalMs": 0,
            "lastMs": 0
        };
        c.samples += 1;
        c.totalMs += elapsed;
        c.lastMs = elapsed;
        root._cost[domain] = c;
        root.revision++;
    }

    function window(channel: string): var {
        const rev = root.revision;
        const buf = root._buffers[channel] ?? [];
        return buf.slice(Math.max(0, buf.length - root.windowSize));
    }

    function previousWindow(channel: string): var {
        const rev = root.revision;
        const buf = root._buffers[channel] ?? [];
        if (buf.length <= root.windowSize)
            return [];
        return buf.slice(Math.max(0, buf.length - root.windowSize * 2), buf.length - root.windowSize);
    }

    function latest(channel: string): real {
        const rev = root.revision;
        const buf = root._buffers[channel] ?? [];
        return buf.length > 0 ? buf[buf.length - 1] : NaN;
    }

    function peak(channel: string): real {
        const w = root.window(channel);
        return w.length > 0 ? Math.max(...w) : NaN;
    }

    function cost(domain: string): var {
        const c = root._cost[domain];
        if (!c)
            return {
                "samples": 0,
                "meanMs": 0,
                "lastMs": 0
            };
        return {
            "samples": c.samples,
            "meanMs": c.samples > 0 ? c.totalMs / c.samples : 0,
            "lastMs": c.lastMs
        };
    }

    readonly property Connections _system: Connections {
        target: Services.SystemUsage

        function onSampled(): void {
            const t = Date.now();
            const s = Services.SystemUsage;
            root._push("cpu", s.cpuPerc);
            if (s.memTotal > 0)
                root._push("mem", s.memPerc);
            if (s.gpuAvailable)
                root._push("gpu", s.gpuPerc);
            if (s.cpuTempAvailable)
                root._push("cpuTemp", s.cpuTemp);
            if (s.gpuTempAvailable)
                root._push("gpuTemp", s.gpuTemp);
            root._record("system", t);
        }
    }

    readonly property Connections _network: Connections {
        target: Services.NetworkUsage

        function onSampled(): void {
            const t = Date.now();
            root._push("netDown", Services.NetworkUsage.downloadSpeed);
            root._push("netUp", Services.NetworkUsage.uploadSpeed);
            root._record("network", t);
        }
    }
}
