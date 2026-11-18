#pragma once

#include <memory>
#include <qhash.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qstringlist.h>
#include <qtranslator.h>

namespace hornero {

// A QTranslator backed directly by a Qt Linguist `.ts` catalog.
//
// The shell is plain QML loaded from its config directory (often a source
// checkout), so it reads the reviewable `.ts` source instead of a compiled
// `.qm` that could go stale. Only finished translations are used:
// `unfinished`, `vanished` and `obsolete` entries fall back to the English
// source text. Lookups try (context, source, disambiguation) first, then the
// source text alone, so dynamic `qsTr(variable)` calls in one file still find
// a string that another file marked for translation.
class TsCatalog : public QTranslator {
    Q_OBJECT

public:
    explicit TsCatalog(QObject* parent = nullptr);

    // Parses `path`; returns false and sets `error` on unreadable or
    // malformed input. A failed load leaves the catalog empty.
    bool loadTs(const QString& path, QString* error = nullptr);

    [[nodiscard]] QString translate(
        const char* context, const char* sourceText, const char* disambiguation, int n) const override;
    [[nodiscard]] bool isEmpty() const override;
    [[nodiscard]] QString catalogLanguage() const;

    [[nodiscard]] int messageCount() const;

    // Plural form index for `n` in `language` (Qt numerus order).
    static int pluralForm(const QString& language, int n);

private:
    static QString key(const QString& context, const QString& source, const QString& disambiguation);

    QHash<QString, QStringList> m_exact;
    QHash<QString, QStringList> m_bySource;
    QString m_language;
};

// QML entry point. Installs one TsCatalog on the application and asks the
// QML engine to re-evaluate every binding that calls qsTr(), so a language
// change applies live. Text assigned imperatively (already-shown toasts,
// strings computed once in handlers) keeps its old language until it is
// rebuilt or the shell restarts.
class Translator : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    // Catalog locale in use, e.g. "es_AR"; "" means the English source text.
    Q_PROPERTY(QString language READ language NOTIFY languageChanged)
    // Finished messages in the active catalog (0 for English).
    Q_PROPERTY(int messageCount READ messageCount NOTIFY languageChanged)
    // Last load problem, "" when the last load succeeded.
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    // The system UI languages, most preferred first (LANGUAGE, LC_ALL,
    // LC_MESSAGES, LANG), as reported by QLocale::system().uiLanguages().
    Q_PROPERTY(QStringList systemLanguages READ systemLanguages CONSTANT)

public:
    explicit Translator(QObject* parent = nullptr);
    ~Translator() override;

    [[nodiscard]] QString language() const;
    [[nodiscard]] int messageCount() const;
    [[nodiscard]] QString error() const;
    [[nodiscard]] QStringList systemLanguages() const;

    // Locales with a `<prefix>_<locale>.ts` catalog in `directory`.
    Q_INVOKABLE QStringList available(const QString& directory, const QString& prefix = QStringLiteral("hornero")) const;

    // Maps a setting ("auto", "en", or a locale such as "es_AR") to the
    // catalog locale to load, "" for English. "auto" walks the system UI
    // languages: the first English entry wins English, the first entry
    // with an exact or same-language catalog wins that catalog.
    Q_INVOKABLE QString resolve(const QString& setting, const QString& directory,
        const QString& prefix = QStringLiteral("hornero")) const;

    // Pure resolution core, exposed for tests.
    static QString resolveAgainst(const QString& setting, const QStringList& uiLanguages, const QStringList& available);

    // Loads `<directory>/<prefix>_<locale>.ts` and retranslates. An empty
    // locale (or "en") removes the catalog. On failure the previous catalog
    // is removed too (English is always a complete fallback) and `error`
    // says why.
    Q_INVOKABLE bool load(
        const QString& locale, const QString& directory, const QString& prefix = QStringLiteral("hornero"));

signals:
    void languageChanged();
    void errorChanged();

private:
    void setError(const QString& error);
    void uninstall();
    void retranslate();

    std::unique_ptr<TsCatalog> m_catalog;
    QString m_language;
    QString m_error;
};

} // namespace hornero
