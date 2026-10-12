#pragma once

#include <qnetworkaccessmanager.h>
#include <qobject.h>
#include <qstring.h>
#include <qqmlengine.h>

namespace hornero {

class Requests : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Requests(QObject* parent = nullptr);

    Q_INVOKABLE void get(const QUrl& url, QJSValue callback, QJSValue onError = QJSValue(), const QString& userAgent = QString()) const;

private:
    QNetworkAccessManager* m_manager;
};

} // namespace hornero
