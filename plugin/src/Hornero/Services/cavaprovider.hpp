#pragma once

#include "audioprovider.hpp"
#include <cava/cavacore.h>
#include <qqmlintegration.h>

namespace hornero::services {

class CavaProcessor : public AudioProcessor {
    Q_OBJECT

public:
    explicit CavaProcessor(QObject* parent = nullptr);
    ~CavaProcessor();

    void setBars(int bars);
    void setChannels(int channels);

signals:
    void valuesChanged(QVector<double> values);

protected:
    void process() override;

private:
    struct cava_plan* m_plan;
    double* m_in;
    double* m_out;

    int m_bars;
    int m_channels;
    QVector<double> m_values;

    void reload();
    void initCava();
    void cleanup();
};

class CavaProvider : public AudioProvider {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int bars READ bars WRITE setBars NOTIFY barsChanged)
    // 1: one mono spectrum (default). 2: stereo; `values` then holds every
    // left band first and then every right band (bars * 2 values).
    Q_PROPERTY(int channels READ channels WRITE setChannels NOTIFY channelsChanged)

    Q_PROPERTY(QVector<double> values READ values NOTIFY valuesChanged)

public:
    explicit CavaProvider(QObject* parent = nullptr);

    [[nodiscard]] int bars() const;
    void setBars(int bars);

    [[nodiscard]] int channels() const;
    void setChannels(int channels);

    [[nodiscard]] QVector<double> values() const;

signals:
    void barsChanged();
    void channelsChanged();
    void valuesChanged();

private:
    int m_bars;
    int m_channels;
    QVector<double> m_values;

    void updateValues(QVector<double> values);
};

} // namespace hornero::services
