// SPDX-License-Identifier: GPL-3.0-only
// QtTest unit suite for the shell translator (ctest: translator-unit).
#include "translator.hpp"

#include <QCoreApplication>
#include <QFile>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

#include <memory>

using hornero::Translator;
using hornero::TsCatalog;
using namespace Qt::StringLiterals;

namespace {

const auto kCatalog = uR"(<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE TS>
<TS version="2.1" language="es_AR" sourcelanguage="en">
<context>
    <name>Probe</name>
    <message>
        <source>Hello</source>
        <translation>Hola</translation>
    </message>
    <message>
        <source>Open %1</source>
        <translation>Abrí %1</translation>
    </message>
    <message>
        <source>Draft</source>
        <translation type="unfinished">Borrador</translation>
    </message>
    <message>
        <source>Gone</source>
        <translation type="vanished">Ido</translation>
    </message>
    <message>
        <source>Close</source>
        <comment>verb</comment>
        <translation>Cerrá</translation>
    </message>
    <message numerus="yes">
        <source>%n update(s)</source>
        <translation>
            <numerusform>%n actualización</numerusform>
            <numerusform>%n actualizaciones</numerusform>
        </translation>
    </message>
</context>
<context>
    <name>Other</name>
    <message>
        <source>Shared label</source>
        <translation>Etiqueta compartida</translation>
    </message>
</context>
</TS>
)"_s;

QString writeCatalog(const QTemporaryDir& dir, const QString& name, const QString& text) {
    const auto path = dir.filePath(name);
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return {};
    file.write(text.toUtf8());
    return path;
}

} // namespace

class TranslatorUnit : public QObject {
    Q_OBJECT

private slots:
    void parsesFinishedMessagesOnly() {
        QTemporaryDir dir;
        TsCatalog catalog;
        QString error;
        QVERIFY(catalog.loadTs(writeCatalog(dir, u"hornero_es_AR.ts"_s, kCatalog), &error));
        QVERIFY2(error.isEmpty(), qPrintable(error));
        QCOMPARE(catalog.catalogLanguage(), u"es_AR"_s);
        // Hello, Open %1, Close(verb), %n update(s), Shared label.
        QCOMPARE(catalog.messageCount(), 5);
        QCOMPARE(catalog.translate("Probe", "Hello", nullptr, -1), u"Hola"_s);
        QCOMPARE(catalog.translate("Probe", "Draft", nullptr, -1), QString());
        QCOMPARE(catalog.translate("Probe", "Gone", nullptr, -1), QString());
        QCOMPARE(catalog.translate("Probe", "Missing", nullptr, -1), QString());
    }

    void disambiguationIsPartOfTheKey() {
        QTemporaryDir dir;
        TsCatalog catalog;
        QVERIFY(catalog.loadTs(writeCatalog(dir, u"c.ts"_s, kCatalog)));
        QCOMPARE(catalog.translate("Probe", "Close", "verb", -1), u"Cerrá"_s);
        QCOMPARE(catalog.translate("Probe", "Close", nullptr, -1), QString());
    }

    void fallsBackToSourceAcrossContexts() {
        QTemporaryDir dir;
        TsCatalog catalog;
        QVERIFY(catalog.loadTs(writeCatalog(dir, u"c.ts"_s, kCatalog)));
        // qsTr(variable) in another file still finds the string.
        QCOMPARE(catalog.translate("BarOrderEditor", "Shared label", nullptr, -1), u"Etiqueta compartida"_s);
    }

    void pluralFormsFollowSpanishRules() {
        QTemporaryDir dir;
        TsCatalog catalog;
        QVERIFY(catalog.loadTs(writeCatalog(dir, u"c.ts"_s, kCatalog)));
        QCOMPARE(catalog.translate("Probe", "%n update(s)", nullptr, 1), u"%n actualización"_s);
        QCOMPARE(catalog.translate("Probe", "%n update(s)", nullptr, 0), u"%n actualizaciones"_s);
        QCOMPARE(catalog.translate("Probe", "%n update(s)", nullptr, 7), u"%n actualizaciones"_s);
        QCOMPARE(TsCatalog::pluralForm(u"fr"_s, 0), 0);
        QCOMPARE(TsCatalog::pluralForm(u"es_AR"_s, 0), 1);
    }

    void malformedCatalogIsRejected() {
        QTemporaryDir dir;
        TsCatalog catalog;
        QString error;
        QVERIFY(!catalog.loadTs(writeCatalog(dir, u"bad.ts"_s, u"<TS><context><name>x</name><message>"_s), &error));
        QVERIFY(!error.isEmpty());
        QVERIFY(catalog.isEmpty());
        QVERIFY(!catalog.loadTs(dir.filePath(u"absent.ts"_s), &error));
    }

    void resolvesSettings() {
        const QStringList available { u"es_AR"_s };
        QCOMPARE(Translator::resolveAgainst(u"auto"_s, { u"es-AR"_s, u"es"_s }, available), u"es_AR"_s);
        // Another Spanish locale gets the closest catalog we ship.
        QCOMPARE(Translator::resolveAgainst(u"auto"_s, { u"es-MX"_s }, available), u"es_AR"_s);
        QCOMPARE(Translator::resolveAgainst(u"auto"_s, { u"en-US"_s, u"es-AR"_s }, available), QString());
        QCOMPARE(Translator::resolveAgainst(u"auto"_s, { u"de-DE"_s, u"es-AR"_s }, available), u"es_AR"_s);
        QCOMPARE(Translator::resolveAgainst(u"auto"_s, { u"C"_s }, available), QString());
        QCOMPARE(Translator::resolveAgainst(u""_s, { u"es_AR.UTF-8"_s }, available), u"es_AR"_s);
        QCOMPARE(Translator::resolveAgainst(u"en"_s, { u"es-AR"_s }, available), QString());
        QCOMPARE(Translator::resolveAgainst(u"es_AR"_s, { u"en-US"_s }, available), u"es_AR"_s);
        QCOMPARE(Translator::resolveAgainst(u"es-AR"_s, { u"en-US"_s }, available), u"es_AR"_s);
        QCOMPARE(Translator::resolveAgainst(u"fr_FR"_s, { u"en-US"_s }, available), QString());
        QCOMPARE(Translator::resolveAgainst(u"es_AR"_s, { u"es-AR"_s }, {}), QString());
    }

    void listsAvailableCatalogs() {
        QTemporaryDir dir;
        writeCatalog(dir, u"hornero_es_AR.ts"_s, kCatalog);
        writeCatalog(dir, u"other_fr.ts"_s, kCatalog);
        Translator translator;
        QCOMPARE(translator.available(dir.path()), QStringList { u"es_AR"_s });
    }

    void appliesLiveToQmlBindings() {
        QTemporaryDir dir;
        writeCatalog(dir, u"hornero_es_AR.ts"_s, kCatalog);

        QQmlEngine engine;
        Translator translator;
        QQmlEngine::setContextForObject(&translator, engine.rootContext());

        QQmlComponent component(&engine);
        component.setData(R"QML(import QtQml
QtObject {
    property int count: 3
    property string greeting: qsTr("Hello")
    property string updates: qsTr("%n update(s)", "", count)
    property string open: qsTr("Open %1").arg("Cockpit")
})QML",
            QUrl(u"file:///probe/Probe.qml"_s));
        std::unique_ptr<QObject> object(component.create());
        QVERIFY2(object, qPrintable(component.errorString()));
        QCOMPARE(object->property("greeting").toString(), u"Hello"_s);

        QSignalSpy changed(&translator, &Translator::languageChanged);
        QVERIFY(translator.load(u"es_AR"_s, dir.path()));
        QCOMPARE(changed.count(), 1);
        QCOMPARE(translator.language(), u"es_AR"_s);
        QCOMPARE(object->property("greeting").toString(), u"Hola"_s);
        QCOMPARE(object->property("updates").toString(), u"3 actualizaciones"_s);
        QCOMPARE(object->property("open").toString(), u"Abrí Cockpit"_s);

        // Back to English: the catalog is removed and bindings re-run.
        QVERIFY(translator.load(u"en"_s, dir.path()));
        QCOMPARE(translator.language(), QString());
        QCOMPARE(object->property("greeting").toString(), u"Hello"_s);
        QCOMPARE(object->property("updates").toString(), u"3 update(s)"_s);
    }

    void failedLoadFallsBackToEnglish() {
        QTemporaryDir dir;
        writeCatalog(dir, u"hornero_es_AR.ts"_s, kCatalog);
        Translator translator;
        QVERIFY(translator.load(u"es_AR"_s, dir.path()));
        QVERIFY(!translator.load(u"pt_BR"_s, dir.path()));
        QCOMPARE(translator.language(), QString());
        QVERIFY(!translator.error().isEmpty());
        QCOMPARE(QCoreApplication::translate("Probe", "Hello"), u"Hello"_s);
    }

    void shippedCatalogParses() {
        const auto path = QStringLiteral(HORNERO_SOURCE_DIR "/i18n/hornero_es_AR.ts");
        TsCatalog catalog;
        QString error;
        QVERIFY2(catalog.loadTs(path, &error), qPrintable(error));
        QCOMPARE(catalog.catalogLanguage(), u"es_AR"_s);
        QVERIFY(catalog.messageCount() > 1000);
    }
};

QTEST_GUILESS_MAIN(TranslatorUnit)
#include "test_translator.moc"
