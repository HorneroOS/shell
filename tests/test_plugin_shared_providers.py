"""Shared extension data providers (shell#377).

Static contract: every telemetry domain a plugin can read through
PluginKit is backed by exactly one shell-owned singleton, the two
polling domains each own exactly one refCount-gated Timer, and the
PluginKit subscription surface forwards leases to those gates
instead of creating a second polling source.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "plugin/qml/Hornero/PluginKit"
SERVICES = ROOT / "services"

DOMAINS = ["system", "network", "media", "weather", "time", "power", "audio"]

DATA_FACADES = ["System", "Network", "Media", "Weather", "Time", "Power", "Audio"]

POLLING_SERVICES = {"SystemUsage": "system", "NetworkUsage": "network"}


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_qmldir_registers_providers_and_subscription():
    qmldir = _read(KIT / "qmldir")
    assert "singleton Providers 1.0 Providers.qml" in qmldir
    assert "Subscription 1.0 Subscription.qml" in qmldir
    assert (KIT / "Providers.qml").is_file()
    assert (KIT / "Subscription.qml").is_file()
    # Existing facades stay registered exactly as before.
    for name in DATA_FACADES:
        assert f"singleton {name} 1.0 {name}.qml" in qmldir, name


def test_providers_covers_all_seven_domains_with_modes():
    src = _read(KIT / "Providers.qml")
    assert src.startswith("pragma Singleton")
    for domain in DOMAINS:
        assert f'"{domain}"' in src, domain
    assert '"polling"' in src
    assert '"cached"' in src
    assert '"event"' in src


def test_subscription_surface_creates_no_polling_source():
    # The whole point of #377: leases must not add timers, processes
    # or file polls of their own anywhere in the subscription path.
    for name in ("Providers.qml", "Subscription.qml"):
        src = _read(KIT / name)
        for forbidden in ("Timer {", "Process {", "FileView {", "SystemClock {"):
            assert forbidden not in src, (name, forbidden)
    # The data facades themselves stay timer/process free too.
    for name in DATA_FACADES:
        src = _read(KIT / f"{name}.qml")
        assert "Timer {" not in src, name
        assert "Process {" not in src, name


def test_single_shared_polling_timer_per_polling_domain():
    # Statically provable single shared polling source: each polling
    # service declares exactly one Timer, gated on its refCount, and
    # it is the only Timer that can drive that domain's reads.
    for service in POLLING_SERVICES:
        src = _read(SERVICES / f"{service}.qml")
        assert src.startswith("pragma Singleton"), service
        assert len(re.findall(r"\bTimer\s*\{", src)) == 1, service
        assert "running: root.refCount > 0" in src, service
        assert "Config.dashboard.resourceUpdateInterval" in src, service


def test_providers_forwards_leases_to_the_shared_refcount_gates():
    src = _read(KIT / "Providers.qml")
    assert "Services.SystemUsage.refCount++" in src
    assert "Services.SystemUsage.refCount--" in src
    assert "Services.NetworkUsage.refCount++" in src
    assert "Services.NetworkUsage.refCount--" in src
    # No other service refCount is touched: event/cached domains have
    # no polling gate to forward to.
    assert len(re.findall(r"\.refCount\+\+", src)) == 2
    assert len(re.findall(r"\.refCount--", src)) == 2


def test_unsubscribe_without_a_lease_is_refused():
    src = _read(KIT / "Providers.qml")
    unsubscribe = src.split("function unsubscribe", 1)[1]
    # The lease count is checked before any decrement, so an
    # unmatched unsubscribe can never drive a service refCount
    # negative and wedge the shared timer off for everyone else.
    guard = unsubscribe.index("<= 0")
    decrement = unsubscribe.index("_leases[domain] -= 1")
    assert guard < decrement
    assert "return false" in unsubscribe


def test_unknown_domain_is_rejected_everywhere():
    src = _read(KIT / "Providers.qml")
    assert "function isDomain" in src
    subscribe = src.split("function subscribe", 1)[1].split("function unsubscribe", 1)[0]
    assert "if (!isDomain(domain))" in subscribe
    assert "return false" in subscribe


def test_subscription_releases_on_destroy_and_on_disable():
    src = _read(KIT / "Subscription.qml")
    assert "Component.onDestruction" in src
    assert "Providers.unsubscribe(_heldDomain)" in src
    assert "onDomainChanged" in src
    assert "onEnabledChanged" in src
    assert "Component.onCompleted" in src
    # Disabling the lease (`enabled: false`) must free the held
    # domain: _sync treats it as "desired is empty" and unsubscribes.
    assert 'const desired = enabled ? domain : "";' in src


def test_refresh_semantics_are_exposed_from_the_shared_config():
    src = _read(KIT / "Providers.qml")
    assert "function refreshIntervalMs" in src
    # Polling domains report the one shared configured interval,
    # never a per-plugin rate.
    assert "Config.dashboard.resourceUpdateInterval" in src
    # Weather reports its hourly TTL.
    assert "3600000" in src
    weather = _read(SERVICES / "Weather.qml")
    assert "interval: 3600000" in weather


def test_docs_describe_shared_providers_and_backoff():
    docs = _read(ROOT / "docs/PLUGINS.md")
    assert "## Shared data providers" in docs
    assert "Subscription { domain:" in docs
    for domain in DOMAINS:
        assert f"`{domain}`" in docs, domain
    assert "backoff" in docs.lower()
    assert "cache" in docs.lower()
    assert "releases its subscriptions" in docs
