#pragma once

#include <QtDBus/qdbusunixfiledescriptor.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qtimer.h>

namespace hornero::internal {

class LogindManager : public QObject {
    Q_OBJECT
    QML_ELEMENT

public:
    explicit LogindManager(QObject* parent = nullptr);
    ~LogindManager() override;

    Q_INVOKABLE void releaseSleepInhibitor();

signals:
    void aboutToSleep();
    void resumed();
    void lockRequested();
    void unlockRequested();

private slots:
    void handlePrepareForSleep(bool sleep);
    void handleLockRequested();
    void handleUnlockRequested();

private:
    void acquireSleepInhibitor();

    QDBusUnixFileDescriptor m_sleepInhibitor;
    QTimer m_inhibitReleaseTimer;
};

} // namespace hornero::internal
