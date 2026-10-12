#include "requests.hpp"

#include <qnetworkaccessmanager.h>
#include <qnetworkreply.h>
#include <qnetworkrequest.h>

namespace hornero {

Requests::Requests(QObject* parent)
    : QObject(parent)
    , m_manager(new QNetworkAccessManager(this)) {}

void Requests::get(const QUrl& url, QJSValue onSuccess, QJSValue onError, const QString& userAgent) const {
    if (!onSuccess.isCallable()) {
        qWarning() << "Requests::get: onSuccess is not callable";
        return;
    }

    QNetworkRequest request(url);
    if (!userAgent.isEmpty())
        request.setRawHeader("User-Agent", userAgent.toUtf8());
    auto reply = m_manager->get(request);

    QObject::connect(reply, &QNetworkReply::finished, [reply, onSuccess, onError]() {
        if (reply->error() == QNetworkReply::NoError) {
            onSuccess.call({ QString(reply->readAll()) });
        } else if (onError.isCallable()) {
            onError.call({ reply->errorString() });
        } else {
            qWarning() << "Requests::get: request failed with error" << reply->errorString();
        }

        reply->deleteLater();
    });
}

} // namespace hornero
