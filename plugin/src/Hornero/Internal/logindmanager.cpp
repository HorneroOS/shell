#include "logindmanager.hpp"

#include <QtDBus/qdbusconnection.h>
#include <QtDBus/qdbuserror.h>
#include <QtDBus/qdbusinterface.h>
#include <QtDBus/qdbusreply.h>
#include <QtDBus/qdbusextratypes.h>

namespace hornero::internal {

LogindManager::LogindManager(QObject* parent)
    : QObject(parent) {
    m_inhibitReleaseTimer.setSingleShot(true);
    m_inhibitReleaseTimer.setInterval(5000);
    QObject::connect(&m_inhibitReleaseTimer, &QTimer::timeout, this, &LogindManager::releaseSleepInhibitor);

    auto bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        qWarning() << "LogindManager::LogindManager: failed to connect to system bus:" << bus.lastError().message();
        return;
    }

    bool ok = bus.connect("org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager",
        "PrepareForSleep", this, SLOT(handlePrepareForSleep(bool)));

    if (!ok) {
        qWarning() << "LogindManager::LogindManager: failed to connect to PrepareForSleep signal:"
            << bus.lastError().message();
    }

    acquireSleepInhibitor();

    QDBusInterface login1("org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", bus);
    const QDBusReply<QDBusObjectPath> reply = login1.call("GetSession", "auto");
    if (!reply.isValid()) {
        qWarning() << "LogindManager::LogindManager: failed to get session path";
        return;
    }
    const auto sessionPath = reply.value().path();

    ok = bus.connect("org.freedesktop.login1", sessionPath, "org.freedesktop.login1.Session", "Lock", this,
        SLOT(handleLockRequested()));

    if (!ok) {
        qWarning() << "LogindManager::LogindManager: failed to connect to Lock signal:" << bus.lastError().message();
    }

    ok = bus.connect("org.freedesktop.login1", sessionPath, "org.freedesktop.login1.Session", "Unlock", this,
        SLOT(handleUnlockRequested()));

    if (!ok) {
        qWarning() << "LogindManager::LogindManager: failed to connect to Unlock signal:" << bus.lastError().message();
    }
}

LogindManager::~LogindManager() {
    releaseSleepInhibitor();
}

void LogindManager::acquireSleepInhibitor() {
    if (m_sleepInhibitor.isValid()) {
        return;
    }

    auto bus = QDBusConnection::systemBus();
    if (!bus.isConnected()) {
        return;
    }

    QDBusInterface login1("org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", bus);
    const QDBusReply<QDBusUnixFileDescriptor> reply =
        login1.call("Inhibit", "sleep", "hornero-shell", "Lock screen before suspend", "delay");
    if (!reply.isValid()) {
        qWarning() << "LogindManager::acquireSleepInhibitor: failed to acquire sleep delay inhibitor:"
            << reply.error().message();
        return;
    }

    m_sleepInhibitor = reply.value();
}

void LogindManager::releaseSleepInhibitor() {
    m_inhibitReleaseTimer.stop();
    if (m_sleepInhibitor.isValid()) {
        m_sleepInhibitor = QDBusUnixFileDescriptor();
    }
}

void LogindManager::handlePrepareForSleep(bool sleep) {
    if (sleep) {
        if (m_sleepInhibitor.isValid()) {
            m_inhibitReleaseTimer.start();
        }
        emit aboutToSleep();
    } else {
        m_inhibitReleaseTimer.stop();
        acquireSleepInhibitor();
        emit resumed();
    }
}

void LogindManager::handleLockRequested() {
    emit lockRequested();
}

void LogindManager::handleUnlockRequested() {
    emit unlockRequested();
}

} // namespace hornero::internal
