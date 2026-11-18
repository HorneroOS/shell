pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // CPU properties
    property string cpuName: ""
    property real cpuPerc
    property real cpuTemp
    // Sensor availability: false until a real reading arrives, so
    // consumers show "unavailable" instead of a fabricated 0.
    property bool cpuTempAvailable: false
    property bool gpuTempAvailable: false
    readonly property bool gpuAvailable: gpuType !== "NONE"

    // Emitted after each /proc/stat sample (PluginKit Telemetry history).
    signal sampled

    // GPU properties
    readonly property string gpuType: Config.services.gpuType.toUpperCase() || autoGpuType
    property string autoGpuType: "NONE"
    property string gpuName: ""
    property real gpuPerc
    property real gpuTemp

    // Memory properties
    property real memUsed
    property real memTotal
    readonly property real memPerc: memTotal > 0 ? memUsed / memTotal : 0

    // Storage properties (aggregated)
    readonly property real storagePerc: {
        let totalUsed = 0;
        let totalSize = 0;
        for (const disk of disks) {
            totalUsed += disk.used;
            totalSize += disk.total;
        }
        return totalSize > 0 ? totalUsed / totalSize : 0;
    }

    // Individual disks: Array of { mount, used, total, free, perc }
    property var disks: []

    property real lastCpuIdle
    property real lastCpuTotal
    // Per-core load 0..1 in /proc/stat order (cpu0, cpu1, ...).
    property var cpuCores: []
    property var _lastCoreIdle: []
    property var _lastCoreTotal: []

    property int refCount

    function cleanCpuName(name: string): string {
        return name.replace(/\(R\)/gi, "").replace(/\(TM\)/gi, "").replace(/CPU/gi, "").replace(/\d+th Gen /gi, "").replace(/\d+nd Gen /gi, "").replace(/\d+rd Gen /gi, "").replace(/\d+st Gen /gi, "").replace(/Core /gi, "").replace(/Processor/gi, "").replace(/\s+/g, " ").trim();
    }

    function cleanGpuName(name: string): string {
        return name.replace(/NVIDIA GeForce /gi, "").replace(/NVIDIA /gi, "").replace(/AMD Radeon /gi, "").replace(/AMD /gi, "").replace(/Intel /gi, "").replace(/\(R\)/gi, "").replace(/\(TM\)/gi, "").replace(/Graphics/gi, "").replace(/\s+/g, " ").trim();
    }

    function formatKib(kib: real): var {
        const mib = 1024;
        const gib = 1024 ** 2;
        const tib = 1024 ** 3;

        if (kib >= tib)
            return {
                value: kib / tib,
                unit: "TiB"
            };
        if (kib >= gib)
            return {
                value: kib / gib,
                unit: "GiB"
            };
        if (kib >= mib)
            return {
                value: kib / mib,
                unit: "MiB"
            };
        return {
            value: kib,
            unit: "KiB"
        };
    }

    // Tiered refresh (shell#651). Only the cheap reads (/proc/stat and
    // /proc/meminfo, two FileViews) follow the experience cadence (1 Hz
    // everyday, 2 Hz signal, paused under fullscreen when the mode asks).
    // The probes that fork a process (`sensors`, the GPU read, `lsblk`)
    // run on their own, slower budget: temperatures move over seconds and
    // disk usage over minutes, so spawning three processes on every 500 ms
    // tick (and re-parsing `lsblk` each time) was the dominant main-thread
    // cost of Signal mode. Both budgets are user settings
    // (Control Center > Dashboard) and never run faster than the cadence.
    readonly property int sensorIntervalMs: Math.max(Experience.telemetryIntervalMs, Config.dashboard.sensorUpdateInterval)
    readonly property int diskIntervalMs: Math.max(root.sensorIntervalMs, Config.dashboard.diskUpdateInterval)
    property double _lastSensorsAt: 0
    property double _lastDisksAt: 0

    // True when `lastAt` is a full interval (minus half a tick of timer
    // jitter) behind `now`.
    function due(lastAt: real, now: real, intervalMs: int): bool {
        return now - lastAt >= intervalMs - Experience.telemetryIntervalMs / 2;
    }

    Timer {
        running: root.refCount > 0 && !Experience.telemetryPaused
        interval: Experience.telemetryIntervalMs
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            const now = Date.now();
            if (root.due(root._lastSensorsAt, now, root.sensorIntervalMs)) {
                root._lastSensorsAt = now;
                gpuUsage.running = true;
                sensors.running = true;
            }
            if (root.due(root._lastDisksAt, now, root.diskIntervalMs)) {
                root._lastDisksAt = now;
                storage.running = true;
            }
        }
    }

    // One-time CPU info detection (name)
    FileView {
        id: cpuinfoInit

        path: "/proc/cpuinfo"
        onLoaded: {
            const nameMatch = text().match(/model name\s*:\s*(.+)/);
            if (nameMatch)
                root.cpuName = root.cleanCpuName(nameMatch[1]);
        }
    }

    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: {
            const data = text().match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
            if (data) {
                const stats = data.slice(1).map(n => parseInt(n, 10));
                const total = stats.reduce((a, b) => a + b, 0);
                const idle = stats[3] + (stats[4] ?? 0);

                const totalDiff = total - root.lastCpuTotal;
                const idleDiff = idle - root.lastCpuIdle;
                root.cpuPerc = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0;

                root.lastCpuTotal = total;
                root.lastCpuIdle = idle;
                root.sampled();
            }
            const cores = [];
            const idles = [];
            const totals = [];
            const coreRe = /^cpu(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/gm;
            let m;
            while ((m = coreRe.exec(text())) !== null) {
                const i = idles.length;
                const v = m.slice(2).map(n => parseInt(n, 10));
                const t = v.reduce((a, b) => a + b, 0);
                const id = v[3] + v[4];
                const dt = t - (root._lastCoreTotal[i] ?? 0);
                const di = id - (root._lastCoreIdle[i] ?? 0);
                cores.push(dt > 0 && root._lastCoreTotal.length > i ? Math.max(0, Math.min(1, 1 - di / dt)) : 0);
                idles.push(id);
                totals.push(t);
            }
            root._lastCoreIdle = idles;
            root._lastCoreTotal = totals;
            root.cpuCores = cores;
        }
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: {
            const data = text();
            root.memTotal = parseInt(data.match(/MemTotal: *(\d+)/)[1], 10) || 1;
            root.memUsed = (root.memTotal - parseInt(data.match(/MemAvailable: *(\d+)/)[1], 10)) || 0;
        }
    }

    Process {
        id: storage

        // Physical disks with the usage of every filesystem mounted from
        // them. PKNAME walks partitions, LUKS (crypt), LVM and RAID nodes up
        // to their disk (shell#464): matching partition names only missed
        // encrypted roots, and unmounted disks counted 0 used against their
        // whole size, so the total read ~0%.
        command: ["lsblk", "-b", "-o", "NAME,PKNAME,SIZE,TYPE,FSUSED,FSSIZE", "-P"]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = root.parseDisks(text);
                // Same array contents: keep the old one so nothing bound
                // to `disks` (storage meters, PluginKit) re-evaluates.
                if (JSON.stringify(next) !== JSON.stringify(root.disks))
                    root.disks = next;
            }
        }
    }

    // Parses `lsblk -b -P -o NAME,PKNAME,SIZE,TYPE,FSUSED,FSSIZE` into
    // [{ mount, used, total, free, perc }] (KiB), one entry per physical disk
    // that has at least one mounted filesystem.
    function parseDisks(text: string): var {
        const nodes = {};
        const order = [];
        for (const line of text.split("\n")) {
            // One pass per line: every KEY="value" pair, not one RegExp
            // built and run per key.
            const pairs = {};
            const pairRe = /(?:^|\s)([A-Z]+)="([^"]*)"/g;
            let m;
            while ((m = pairRe.exec(line)) !== null)
                pairs[m[1]] = m[2];
            const field = key => pairs[key] ?? "";
            const name = field("NAME");
            if (name === "")
                continue;
            nodes[name] = {
                parent: field("PKNAME"),
                type: field("TYPE"),
                used: parseInt(field("FSUSED") || "0", 10) || 0,
                size: parseInt(field("FSSIZE") || "0", 10) || 0
            };
            order.push(name);
        }

        const diskOf = name => {
            let cur = name;
            for (let hops = 0; hops < 16 && nodes[cur]; hops++) {
                if (nodes[cur].type === "disk")
                    return cur;
                cur = nodes[cur].parent;
            }
            return "";
        };

        const usage = {};
        for (const name of order) {
            const node = nodes[name];
            if (node.size <= 0)
                continue;
            const disk = diskOf(name);
            if (disk === "" || disk.startsWith("zram"))
                continue;
            usage[disk] = usage[disk] || { used: 0, total: 0 };
            usage[disk].used += node.used;
            usage[disk].total += node.size;
        }

        return Object.keys(usage).sort().map(disk => {
            const u = usage[disk];
            return {
                mount: disk,
                used: u.used / 1024,
                total: u.total / 1024,
                free: (u.total - u.used) / 1024,
                perc: u.total > 0 ? u.used / u.total : 0
            };
        });
    }

    // GPU name detection (one-time)
    Process {
        id: gpuNameDetect

        running: true
        command: ["sh", "-c", "nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || lspci 2>/dev/null | grep -i 'vga\\|3d\\|display' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (!output)
                    return;

                // Check if it's from nvidia-smi (clean GPU name)
                if (output.toLowerCase().includes("nvidia") || output.toLowerCase().includes("geforce") || output.toLowerCase().includes("rtx") || output.toLowerCase().includes("gtx")) {
                    root.gpuName = root.cleanGpuName(output);
                } else {
                    // Parse lspci output: extract name from brackets or after colon
                    const bracketMatch = output.match(/\[([^\]]+)\]/);
                    if (bracketMatch) {
                        root.gpuName = root.cleanGpuName(bracketMatch[1]);
                    } else {
                        const colonMatch = output.match(/:\s*(.+)/);
                        if (colonMatch)
                            root.gpuName = root.cleanGpuName(colonMatch[1]);
                    }
                }
            }
        }
    }

    Process {
        id: gpuTypeCheck

        running: !Config.services.gpuType
        command: ["sh", "-c", "if command -v nvidia-smi &>/dev/null && nvidia-smi -L &>/dev/null; then echo NVIDIA; elif ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | grep -q .; then echo GENERIC; else echo NONE; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.autoGpuType = text.trim()
        }
    }

    Process {
        id: gpuUsage

        command: root.gpuType === "GENERIC" ? ["sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent"] : root.gpuType === "NVIDIA" ? ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"] : ["echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.gpuType === "GENERIC") {
                    const percs = text.trim().split("\n");
                    const sum = percs.reduce((acc, d) => acc + parseInt(d, 10), 0);
                    root.gpuPerc = sum / percs.length / 100;
                } else if (root.gpuType === "NVIDIA") {
                    const [usage, temp] = text.trim().split(",");
                    root.gpuPerc = parseInt(usage, 10) / 100;
                    root.gpuTemp = parseInt(temp, 10);
                    root.gpuTempAvailable = isFinite(root.gpuTemp);
                } else {
                    root.gpuPerc = 0;
                    root.gpuTemp = 0;
                }
            }
        }
    }

    Process {
        id: sensors

        command: ["sensors"]
        environment: ({
                LANG: "C.UTF-8",
                LC_ALL: "C.UTF-8"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                let cpuTemp = text.match(/(?:Package id [0-9]+|Tdie):\s+((\+|-)[0-9.]+)(°| )C/);
                if (!cpuTemp)
                    // If AMD Tdie pattern failed, try fallback on Tctl
                    cpuTemp = text.match(/Tctl:\s+((\+|-)[0-9.]+)(°| )C/);

                if (cpuTemp)
                    root.cpuTemp = parseFloat(cpuTemp[1]);
                root.cpuTempAvailable = !!cpuTemp;

                if (root.gpuType !== "GENERIC")
                    return;

                let eligible = false;
                let sum = 0;
                let count = 0;

                for (const line of text.trim().split("\n")) {
                    if (line === "Adapter: PCI adapter")
                        eligible = true;
                    else if (line === "")
                        eligible = false;
                    else if (eligible) {
                        let match = line.match(/^(temp[0-9]+|GPU core|edge)+:\s+\+([0-9]+\.[0-9]+)(°| )C/);
                        if (!match)
                            // Fall back to junction/mem if GPU doesn't have edge temp (for AMD GPUs)
                            match = line.match(/^(junction|mem)+:\s+\+([0-9]+\.[0-9]+)(°| )C/);

                        if (match) {
                            sum += parseFloat(match[2]);
                            count++;
                        }
                    }
                }

                root.gpuTemp = count > 0 ? sum / count : 0;
                root.gpuTempAvailable = count > 0;
            }
        }
    }
}
