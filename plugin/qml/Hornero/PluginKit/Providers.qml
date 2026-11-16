pragma Singleton

import qs.config
import qs.services as Services
import Hornero.Services
import QtQuick

// Shared data providers (RFC 0001 §5b). One lease registry over the
// telemetry domains the facades read. Every domain is backed by exactly
// one shell-owned service, so N extensions reading the same domain share
// that service's work instead of each running its own timer or process.
//
//   polling — "system" (CPU/GPU/memory/temperatures/storage) and
//             "network" (throughput). One Timer each, running only while
//             a lease is held. While any lease is held the cheap /proc
//             reads run at the experience cadence (1 Hz everyday, 2 Hz in
//             the `signal` experience, Theme.telemetryIntervalMs);
//             subprocess probes (sensors, GPU, lsblk) keep the configured
//             dashboard interval.
//   stream  — "spectrum": the shared PipeWire visualiser analysis, started
//             only while a lease is held.
//   cached  — "weather": one shared fetch per location, hourly.
//   event   — "media", "audio", "power", "time", "workspaces": pushed by
//             their daemon/compositor; a lease records interest only.
//
// Leases are aggregate (a caller cannot release another's lease) and an
// unmatched unsubscribe is refused. Extensions declare the domains they
// use in `capabilities.providers`; scripts/validate_plugin.py rejects
// undeclared use. Prefer the declarative Subscription component, which
// releases automatically when the extension surface is destroyed.
QtObject {
    id: root

    readonly property var domains: ["system", "network", "spectrum", "media", "audio", "power", "weather", "time", "workspaces"]

    property var _leases: ({})
    property int _leaseEpoch: 0

    readonly property int _spectrumLeases: root.subscriberCount("spectrum")

    // The spectrum analyser is a reference-counted native service.
    readonly property ServiceRef _spectrumRef: ServiceRef {
        service: root._spectrumLeases > 0 ? Services.Audio.cava : null
    }

    function isDomain(domain: string): bool {
        return domains.includes(domain);
    }

    // "polling" | "stream" | "cached" | "event" | "" for an unknown domain.
    function mode(domain: string): string {
        if (domain === "system" || domain === "network")
            return "polling";
        if (domain === "spectrum")
            return "stream";
        if (domain === "weather")
            return "cached";
        if (isDomain(domain))
            return "event";
        return "";
    }

    // Effective refresh period in ms: the polling interval for polling
    // domains, the weather TTL for the cached domain, 0 for event and
    // stream domains (pushed, never polled), -1 when unknown.
    function refreshIntervalMs(domain: string): int {
        if (domain === "system")
            return Config.dashboard.resourceUpdateInterval;
        if (domain === "network")
            return Config.dashboard.resourceUpdateInterval;
        if (domain === "weather")
            return 3600000;
        if (isDomain(domain))
            return 0;
        return -1;
    }

    function subscriberCount(domain: string): int {
        const epoch = _leaseEpoch;
        return _leases[domain] ?? 0;
    }

    // Whether the shared provider is producing fresh data right now.
    function active(domain: string): bool {
        if (domain === "system")
            return Services.SystemUsage.refCount > 0;
        if (domain === "network")
            return Services.NetworkUsage.refCount > 0;
        if (domain === "spectrum")
            return root._spectrumLeases > 0;
        if (domain === "weather")
            return Services.Weather.locationConfigured;
        return isDomain(domain);
    }

    function subscribe(domain: string): bool {
        if (!isDomain(domain))
            return false;
        _leases[domain] = (_leases[domain] ?? 0) + 1;
        _leaseEpoch++;
        if (domain === "system")
            Services.SystemUsage.refCount++;
        else if (domain === "network")
            Services.NetworkUsage.refCount++;
        return true;
    }

    function unsubscribe(domain: string): bool {
        if (!isDomain(domain) || (_leases[domain] ?? 0) <= 0)
            return false;
        _leases[domain] -= 1;
        _leaseEpoch++;
        if (domain === "system")
            Services.SystemUsage.refCount--;
        else if (domain === "network")
            Services.NetworkUsage.refCount--;
        return true;
    }

    // Measured cost of the PluginKit side of a polling domain: samples
    // taken and the mean/last JS handling time per sample (ms). The
    // service's own /proc reads are measured on the host (docs/PLUGINS.md
    // "Instrumentation cost").
    function cost(domain: string): var {
        return Telemetry.cost(domain);
    }
}
