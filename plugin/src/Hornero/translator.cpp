#include "translator.hpp"

#include <qcoreapplication.h>
#include <qdir.h>
#include <qfile.h>
#include <qlocale.h>
#include <qdebug.h>
#include <qqmlengine.h>
#include <qregularexpression.h>
#include <qxmlstream.h>

namespace hornero {

namespace {

QString normalizeLocale(QString locale) {
    locale.replace(QLatin1Char('-'), QLatin1Char('_'));
    // Drop encoding/modifier suffixes: es_AR.UTF-8@euro -> es_AR.
    const auto cut = locale.indexOf(QRegularExpression(QStringLiteral("[.@]")));
    if (cut >= 0)
        locale.truncate(cut);
    return locale;
}

QString languageOf(const QString& locale) {
    return locale.section(QLatin1Char('_'), 0, 0).toLower();
}

} // namespace

TsCatalog::TsCatalog(QObject* parent)
    : QTranslator(parent) {}

QString TsCatalog::key(const QString& context, const QString& source, const QString& disambiguation) {
    return context + QChar(0x1f) + source + QChar(0x1f) + disambiguation;
}

bool TsCatalog::loadTs(const QString& path, QString* error) {
    m_exact.clear();
    m_bySource.clear();
    m_language.clear();

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        if (error)
            *error = QStringLiteral("cannot read %1: %2").arg(path, file.errorString());
        return false;
    }

    QXmlStreamReader xml(&file);
    QString context;
    while (!xml.atEnd()) {
        xml.readNext();
        if (!xml.isStartElement())
            continue;
        const auto name = xml.name();
        if (name == QLatin1String("TS")) {
            m_language = normalizeLocale(xml.attributes().value(QLatin1String("language")).toString());
        } else if (name == QLatin1String("name")) {
            context = xml.readElementText();
        } else if (name == QLatin1String("message")) {
            QString source;
            QString disambiguation;
            QStringList forms;
            bool finished = false;
            while (!(xml.isEndElement() && xml.name() == QLatin1String("message")) && !xml.atEnd()) {
                xml.readNext();
                if (!xml.isStartElement())
                    continue;
                const auto child = xml.name();
                if (child == QLatin1String("source")) {
                    source = xml.readElementText();
                } else if (child == QLatin1String("comment")) {
                    disambiguation = xml.readElementText();
                } else if (child == QLatin1String("translation")) {
                    const auto type = xml.attributes().value(QLatin1String("type"));
                    finished = type.isEmpty();
                    // Either plain text or <numerusform> children.
                    QString text;
                    while (!(xml.isEndElement() && xml.name() == QLatin1String("translation")) && !xml.atEnd()) {
                        xml.readNext();
                        if (xml.isCharacters())
                            text += xml.text();
                        else if (xml.isStartElement() && xml.name() == QLatin1String("numerusform"))
                            forms << xml.readElementText();
                    }
                    if (forms.isEmpty() && !text.trimmed().isEmpty())
                        forms << text;
                }
            }
            if (!finished || source.isEmpty() || forms.isEmpty() || forms.first().isEmpty())
                continue;
            m_exact.insert(key(context, source, disambiguation), forms);
            const auto sourceKey = key(QString(), source, disambiguation);
            if (!m_bySource.contains(sourceKey))
                m_bySource.insert(sourceKey, forms);
        }
    }

    if (xml.hasError()) {
        if (error)
            *error = QStringLiteral("%1:%2: %3").arg(path).arg(xml.lineNumber()).arg(xml.errorString());
        m_exact.clear();
        m_bySource.clear();
        return false;
    }
    return true;
}

int TsCatalog::pluralForm(const QString& language, int n) {
    const auto lang = languageOf(language);
    // French and Brazilian Portuguese treat 0 as singular; Spanish,
    // English and most Western languages only 1.
    if (lang == QLatin1String("fr") || language == QLatin1String("pt_BR"))
        return n > 1 ? 1 : 0;
    return n == 1 ? 0 : 1;
}

QString TsCatalog::translate(const char* context, const char* sourceText, const char* disambiguation, int n) const {
    const auto source = QString::fromUtf8(sourceText);
    const auto disamb = QString::fromUtf8(disambiguation);
    // Stored lists are never empty (loadTs skips those), so empty = miss.
    auto forms = m_exact.value(key(QString::fromUtf8(context), source, disamb));
    if (forms.isEmpty())
        forms = m_bySource.value(key(QString(), source, disamb));
    if (forms.isEmpty())
        return {};
    if (n < 0 || forms.size() == 1)
        return forms.first();
    return forms.at(qMin(pluralForm(m_language, n), static_cast<int>(forms.size()) - 1));
}

bool TsCatalog::isEmpty() const {
    return m_exact.isEmpty();
}

QString TsCatalog::catalogLanguage() const {
    return m_language;
}

int TsCatalog::messageCount() const {
    return static_cast<int>(m_exact.size());
}

Translator::Translator(QObject* parent)
    : QObject(parent) {}

Translator::~Translator() {
    uninstall();
}

QString Translator::language() const {
    return m_language;
}

int Translator::messageCount() const {
    return m_catalog ? m_catalog->messageCount() : 0;
}

QString Translator::error() const {
    return m_error;
}

QStringList Translator::systemLanguages() const {
    return QLocale::system().uiLanguages();
}

QStringList Translator::available(const QString& directory, const QString& prefix) const {
    QStringList out;
    const QDir dir(directory);
    const auto stem = prefix + QLatin1Char('_');
    for (const auto& entry : dir.entryList({ stem + QStringLiteral("*.ts") }, QDir::Files, QDir::Name))
        out << entry.mid(stem.size(), entry.size() - stem.size() - 3);
    return out;
}

QString Translator::resolveAgainst(
    const QString& setting, const QStringList& uiLanguages, const QStringList& available) {
    const auto match = [&available](const QString& wanted) -> QString {
        const auto locale = normalizeLocale(wanted);
        if (locale.isEmpty())
            return {};
        for (const auto& candidate : available)
            if (candidate.compare(locale, Qt::CaseInsensitive) == 0)
                return candidate;
        const auto lang = languageOf(locale);
        for (const auto& candidate : available)
            if (languageOf(candidate) == lang)
                return candidate;
        return {};
    };

    const auto wanted = normalizeLocale(setting.trimmed());
    if (wanted.isEmpty() || wanted.compare(QLatin1String("auto"), Qt::CaseInsensitive) == 0) {
        for (const auto& ui : uiLanguages) {
            const auto locale = normalizeLocale(ui);
            const auto lang = languageOf(locale);
            if (lang == QLatin1String("en") || lang == QLatin1String("c") || lang == QLatin1String("posix"))
                return {};
            const auto found = match(locale);
            if (!found.isEmpty())
                return found;
        }
        return {};
    }
    if (languageOf(wanted) == QLatin1String("en"))
        return {};
    return match(wanted);
}

QString Translator::resolve(const QString& setting, const QString& directory, const QString& prefix) const {
    return resolveAgainst(setting, systemLanguages(), available(directory, prefix));
}

bool Translator::load(const QString& locale, const QString& directory, const QString& prefix) {
    const auto wanted = normalizeLocale(locale);
    if (wanted.isEmpty() || languageOf(wanted) == QLatin1String("en")) {
        const bool changed = m_catalog != nullptr;
        uninstall();
        setError({});
        if (changed) {
            m_language.clear();
            emit languageChanged();
            retranslate();
        }
        return true;
    }
    if (m_catalog && m_language == wanted)
        return true;

    auto catalog = std::make_unique<TsCatalog>();
    QString problem;
    const auto path = QDir(directory).filePath(QStringLiteral("%1_%2.ts").arg(prefix, wanted));
    const bool ok = catalog->loadTs(path, &problem);
    uninstall();
    if (ok) {
        m_catalog = std::move(catalog);
        QCoreApplication::installTranslator(m_catalog.get());
        m_language = wanted;
    } else {
        qWarning() << "Translator: falling back to English:" << problem;
        m_language.clear();
    }
    setError(problem);
    emit languageChanged();
    retranslate();
    return ok;
}

void Translator::setError(const QString& error) {
    if (m_error == error)
        return;
    m_error = error;
    emit errorChanged();
}

void Translator::uninstall() {
    if (!m_catalog)
        return;
    if (QCoreApplication::instance())
        QCoreApplication::removeTranslator(m_catalog.get());
    m_catalog.reset();
}

void Translator::retranslate() {
    if (auto* engine = qmlEngine(this))
        engine->retranslate();
}

} // namespace hornero
