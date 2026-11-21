#include "cavaprovider.hpp"

#include "audiocollector.hpp"
#include "audioprovider.hpp"
#include <QLibrary>
#include <QMetaObject>
#include <QVector>
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <mutex>
#include <qdebug.h>

namespace hornero::services {

namespace {

// Runtime-resolved libcava ABI (cava/cavacore.h). The plugin used to
// link libcava, so any transitive SONAME break in it (e.g. sndio
// 1.11 dropping libsndio.so.7, which the AUR libcava was built
// against) made the dynamic loader refuse the whole plugin and the
// shell failed to start. Resolving at runtime confines that failure
// to a silent spectrum.
struct CavaApi {
    using Init = struct cava_plan* (*)(int, unsigned int, int, int, double, int, int);
    using Execute = void (*)(double*, int, double*, struct cava_plan*);
    using Destroy = void (*)(struct cava_plan*);

    Init init = nullptr;
    Execute execute = nullptr;
    Destroy destroy = nullptr;
};

const CavaApi& cavaApi() {
    static const CavaApi api = [] {
        // Intentionally leaked: resolved pointers must stay valid.
        auto* lib = new QLibrary(QStringLiteral("cava"));
        if (!lib->load()) {
            const QString error = lib->errorString();
            delete lib;
            lib = new QLibrary(QStringLiteral("libcava.so.1"));
            if (!lib->load()) {
                qWarning() << "CavaProvider: libcava unavailable (" << error << "); spectrum disabled";
                delete lib;
                return CavaApi {};
            }
        }
        CavaApi resolved;
        resolved.init = reinterpret_cast<CavaApi::Init>(lib->resolve("cava_init"));
        resolved.execute = reinterpret_cast<CavaApi::Execute>(lib->resolve("cava_execute"));
        resolved.destroy = reinterpret_cast<CavaApi::Destroy>(lib->resolve("cava_destroy"));
        if (!resolved.init || !resolved.execute || !resolved.destroy) {
            qWarning() << "CavaProvider: libcava missing cava_init/cava_execute/cava_destroy; spectrum disabled";
            return CavaApi {};
        }
        return resolved;
    }();
    return api;
}

struct cava_plan* cava_init(int bars, unsigned int rate, int channels, int autosens, double noise, int low, int high) {
    const auto& api = cavaApi();
    return api.init ? api.init(bars, rate, channels, autosens, noise, low, high) : nullptr;
}

void cava_execute(double* in, int samples, double* out, struct cava_plan* plan) {
    const auto& api = cavaApi();
    if (api.execute)
        api.execute(in, samples, out, plan);
}

void cava_destroy(struct cava_plan* plan) {
    const auto& api = cavaApi();
    if (api.destroy)
        api.destroy(plan);
}

// FFTW's planner (inside cava_init / cava_destroy) is not thread-safe, and
// every CavaProvider runs its processor on its own thread (the mono
// spectrum and the deck's stereo one can start together), so plan creation
// and destruction are serialised. cava_execute only runs existing plans,
// which FFTW allows concurrently.
std::mutex& planMutex() {
    static std::mutex m;
    return m;
}

} // namespace

CavaProcessor::CavaProcessor(QObject* parent)
    : AudioProcessor(parent)
    , m_plan(nullptr)
    , m_in(new double[ac::CHUNK_SIZE * ac::CHANNELS])
    , m_out(nullptr)
    , m_bars(0)
    , m_channels(1) {};

CavaProcessor::~CavaProcessor() {
    cleanup();
    delete[] m_in;
}

void CavaProcessor::process() {
    if (!m_plan || m_bars == 0 || !m_out) {
        return;
    }

    const bool stereo = m_channels == 2;
    // cava counts interleaved samples, so a stereo chunk is 2 * frames.
    const int count = stereo ? static_cast<int>(AudioCollector::instance().readStereoChunk(m_in)) * 2
                             : static_cast<int>(AudioCollector::instance().readChunk(m_in));

    // Silence that has already drained (below one segment): skip the FFT.
    // A paused or idle stream delivers exact zeros, so this is the common
    // idle case and keeps the sampler, and every spectrum fed by it, asleep.
    const bool silentIn = std::all_of(m_in, m_in + count, [](double s) { return std::fpclassify(s) == FP_ZERO; });
    const bool drained = std::all_of(m_values.cbegin(), m_values.cend(), [](double v) { return v < 1e-3; });
    if (silentIn && drained) {
        if (std::any_of(m_values.cbegin(), m_values.cend(), [](double v) { return v > 0.0; })) {
            m_values.fill(0.0);
            emit valuesChanged(m_values);
        }
        return;
    }

    // Process in data via cava
    cava_execute(m_in, count, m_out, m_plan);

    // Apply monstercat filter, per channel: cava puts every left band
    // first, then every right band.
    QVector<double> values(m_bars * m_channels);
    const double inv = 1.0 / 1.5;
    for (int c = 0; c < m_channels; ++c) {
        const int base = c * m_bars;

        // Left to right pass
        double carry = 0.0;
        for (int i = 0; i < m_bars; ++i) {
            carry = std::max(m_out[base + i], carry * inv);
            values[base + i] = carry;
        }

        // Right to left pass and combine
        carry = 0.0;
        for (int i = m_bars - 1; i >= 0; --i) {
            carry = std::max(m_out[base + i], carry * inv);
            values[base + i] = std::max(values[base + i], carry);
        }
    }

    // Update values
    if (values != m_values) {
        m_values = std::move(values);
        emit valuesChanged(m_values);
    }
}

void CavaProcessor::setBars(int bars) {
    if (bars < 0) {
        qWarning() << "CavaProcessor::setBars: bars must be greater than 0. Setting to 0.";
        bars = 0;
    }

    if (m_bars != bars) {
        m_bars = bars;
        reload();
    }
}

void CavaProcessor::setChannels(int channels) {
    channels = channels == 2 ? 2 : 1;
    if (m_channels != channels) {
        m_channels = channels;
        reload();
    }
}

void CavaProcessor::reload() {
    cleanup();
    initCava();
}

void CavaProcessor::cleanup() {
    if (m_plan) {
        const std::lock_guard lock(planMutex());
        cava_destroy(m_plan);
        m_plan = nullptr;
    }

    if (m_out) {
        delete[] m_out;
        m_out = nullptr;
    }
}

void CavaProcessor::initCava() {
    if (m_plan || m_bars == 0) {
        return;
    }

    {
        const std::lock_guard lock(planMutex());
        m_plan = cava_init(m_bars, ac::SAMPLE_RATE, m_channels, 1, 0.85, 50, 10000);
    }
    m_out = new double[static_cast<size_t>(m_bars * m_channels)];
}

CavaProvider::CavaProvider(QObject* parent)
    : AudioProvider(parent)
    , m_bars(0)
    , m_channels(1)
    , m_values(m_bars, 0.0) {
    m_processor = new CavaProcessor();
    init();

    connect(static_cast<CavaProcessor*>(m_processor), &CavaProcessor::valuesChanged, this, &CavaProvider::updateValues);
}

int CavaProvider::bars() const {
    return m_bars;
}

void CavaProvider::setBars(int bars) {
    if (bars < 0) {
        qWarning() << "CavaProvider::setBars: bars must be greater than 0. Setting to 0.";
        bars = 0;
    }

    if (m_bars == bars) {
        return;
    }

    m_values.resize(bars * m_channels, 0.0);
    m_bars = bars;
    emit barsChanged();
    emit valuesChanged();

    // NOTE: Qt < 6.5 has no invokeMethod overload for member pointers with
    // arguments, so route through an argument-free lambda (same semantics).
    auto* processor = static_cast<CavaProcessor*>(m_processor);
    QMetaObject::invokeMethod(processor, [processor, bars]() { processor->setBars(bars); }, Qt::QueuedConnection);
}

int CavaProvider::channels() const {
    return m_channels;
}

void CavaProvider::setChannels(int channels) {
    channels = channels == 2 ? 2 : 1;
    if (m_channels == channels) {
        return;
    }

    m_channels = channels;
    m_values.fill(0.0, m_bars * m_channels);
    emit channelsChanged();
    emit valuesChanged();

    auto* processor = static_cast<CavaProcessor*>(m_processor);
    QMetaObject::invokeMethod(processor, [processor, channels]() { processor->setChannels(channels); }, Qt::QueuedConnection);
}

QVector<double> CavaProvider::values() const {
    return m_values;
}

void CavaProvider::updateValues(QVector<double> values) {
    if (values != m_values) {
        m_values = values;
        emit valuesChanged();
    }
}

} // namespace hornero::services
