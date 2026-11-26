#pragma once

#include "service.hpp"
#include <atomic>
#include <pipewire/pipewire.h>
#include <qmutex.h>
#include <qqmlintegration.h>
#include <spa/param/audio/format-utils.h>
#include <stop_token>
#include <thread>
#include <vector>

namespace hornero::services {

namespace ac {

constexpr quint32 SAMPLE_RATE = 44100;
constexpr quint32 CHUNK_SIZE = 512;
constexpr quint32 CHANNELS = 2; // captured interleaved; mono readers get the downmix

} // namespace ac

class AudioCollector;

class PipeWireWorker {
public:
    explicit PipeWireWorker(std::stop_token token, AudioCollector* collector);

    void run();

private:
    pw_main_loop* m_loop;
    pw_stream* m_stream;
    spa_source* m_timer;
    bool m_idle;

    std::stop_token m_token;
    AudioCollector* m_collector;

    static void handleTimeout(void* data, uint64_t expirations);
    void streamStateChanged(pw_stream_state state);
    void processStream();

    [[nodiscard]] unsigned int nextPowerOf2(unsigned int n);
};

class AudioCollector : public Service {
    Q_OBJECT

public:
    AudioCollector(const AudioCollector&) = delete;
    AudioCollector& operator=(const AudioCollector&) = delete;

    static AudioCollector& instance();

    void clearBuffer();
    // `count` interleaved stereo samples (L, R, L, R, ...).
    void loadChunk(const qint16* samples, quint32 count);
    // Mono downmix, `count` frames (0 = a whole chunk).
    quint32 readChunk(float* out, quint32 count = 0);
    quint32 readChunk(double* out, quint32 count = 0);
    // Interleaved stereo, `frames` frames (0 = a whole chunk); `out` holds
    // 2 * frames values. Returns the frame count.
    quint32 readStereoChunk(double* out, quint32 frames = 0);

private:
    explicit AudioCollector(QObject* parent = nullptr);
    ~AudioCollector();

    std::jthread m_thread;
    // One captured chunk: the mono downmix every reader has always used, and
    // the interleaved stereo frames for the L/R spectrum.
    struct Chunk {
        std::vector<float> mono;
        std::vector<float> stereo;
    };

    static constexpr quint32 READY_NEW_DATA = 4u;

    Chunk m_buffers[3];
    quint32 m_writeIdx;
    std::atomic<quint32> m_readyState;
    quint32 m_readIdx;
    QMutex m_readMutex;
    quint32 m_sampleCount;

    const Chunk& acquireReadChunk();

    void reload();
    void start() override;
    void stop() override;
};

} // namespace hornero::services
