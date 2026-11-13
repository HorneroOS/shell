pragma Singleton

import qs.config
import qs.services as Services
import QtQuick

// Shared data providers (shell#377): one lease registry over the
// telemetry domains the data facades read (System, Network, Media,
// Weather, Time, Power, Audio). Every domain is backed by exactly one
// shell-owned singleton, so N plugins reading the same domain share
// that singleton's work instead of each running its own timer or
// subprocess:
//
//   - "system" / "network" are the only polling domains. Their
//     services each own a single Timer gated on `refCount > 0`;
//     subscribe() forwards one reference to that gate and
//     unsubscribe() releases it. At zero references (no plugin
//     subscription and no shell surface holding a reference) the
//     timer stops and no /proc reads or child processes run at all.
//   - "weather" is a cached domain: the Weather service performs one
//     shared fetch per location, caches the parsed result, and
//     refreshes on its own hourly timer. A lease records interest
//     only; it never starts a second fetch.
//   - "media" (MPRIS), "audio" (PipeWire), "power" (UPower) and
//     "time" (SystemClock) are event-driven: the daemon/clock pushes
//     changes into the shared singleton, so there is nothing to poll
//     and a lease records interest only.
//
// Subscriptions are leases, not identity: counts are aggregate, a
// caller cannot release another caller's lease by name, and an
// unsubscribe with no matching lease is refused instead of driving a
// service refCount negative. Reading a facade without subscribing
// keeps working exactly as before — the values are whatever the
// shared singleton currently holds (live while anyone holds a
// reference, last-known otherwise). Prefer the declarative
// Subscription component, which releases automatically when the
// plugin item is destroyed (including when the host unloads a
// disabled plugin).
QtObject {
    readonly property var domains: ["system", "network", "media", "weather", "time", "power", "audio"]

    property var _leases: ({})
    property int _leaseEpoch: 0

    function isDomain(domain: string): bool {
        return domains.includes(domain);
    }

    // "polling" | "cached" | "event" | "" for an unknown domain.
    function mode(domain: string): string {
        if (domain === "system" || domain === "network")
            return "polling";
        if (domain === "weather")
            return "cached";
        if (domain === "media" || domain === "time" || domain === "power" || domain === "audio")
            return "event";
        return "";
    }

    // Shared refresh period in milliseconds: the one polling interval
    // for polling domains, the weather TTL for the cached domain, 0
    // for event domains (pushed, never polled), -1 when unknown.
    function refreshIntervalMs(domain: string): int {
        if (domain === "system" || domain === "network")
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

    // Whether the shared provider is currently producing fresh data:
    // polling domains only while at least one reference (plugin
    // subscription or shell surface) keeps their timer running;
    // cached/event domains are pushed by their service whenever the
    // underlying source is available.
    function active(domain: string): bool {
        if (domain === "system")
            return Services.SystemUsage.refCount > 0;
        if (domain === "network")
            return Services.NetworkUsage.refCount > 0;
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
}
