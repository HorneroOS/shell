#pragma once

#include "spectrumballistics.hpp"

#include <qcolor.h>
#include <qabstractanimation.h>
#include <qlist.h>
#include <qqmlintegration.h>
#include <qquickitem.h>

namespace hornero::internal {

// One scene-graph item that draws a whole spectrum (Signal Bezel §6.2):
// every band as a column of square-topped segments (or one flat bar when
// `segment` is 0), the hot zone above `hotThreshold` in `hotColor`, and a
// thin peak-hold tick per band. Levels follow VU ballistics (see
// spectrumballistics.hpp). The item only steps and repaints while
// something moves: once every band and peak has settled it disconnects
// from the frame clock and costs nothing until `values` change again.
class SpectrumMeter : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QList<double> values READ values WRITE setValues NOTIFY valuesChanged)
    Q_PROPERTY(int bands READ bands WRITE setBands NOTIFY bandsChanged)
    // Read only values[sliceStart, sliceStart + sliceLength) (0 = to the end),
    // e.g. one channel of a stereo CavaProvider.
    Q_PROPERTY(int sliceStart READ sliceStart WRITE setSliceStart NOTIFY bandsChanged)
    Q_PROPERTY(int sliceLength READ sliceLength WRITE setSliceLength NOTIFY bandsChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(Direction direction READ direction WRITE setDirection NOTIFY geometryParamsChanged)
    Q_PROPERTY(bool reversed READ reversed WRITE setReversed NOTIFY geometryParamsChanged)
    Q_PROPERTY(qreal segment READ segment WRITE setSegment NOTIFY geometryParamsChanged)
    Q_PROPERTY(qreal segmentGap READ segmentGap WRITE setSegmentGap NOTIFY geometryParamsChanged)
    Q_PROPERTY(qreal bandGap READ bandGap WRITE setBandGap NOTIFY geometryParamsChanged)
    Q_PROPERTY(qreal peakThickness READ peakThickness WRITE setPeakThickness NOTIFY geometryParamsChanged)
    Q_PROPERTY(QColor onColor READ onColor WRITE setOnColor NOTIFY coloursChanged)
    Q_PROPERTY(QColor hotColor READ hotColor WRITE setHotColor NOTIFY coloursChanged)
    Q_PROPERTY(QColor offColor READ offColor WRITE setOffColor NOTIFY coloursChanged)
    Q_PROPERTY(QColor peakColor READ peakColor WRITE setPeakColor NOTIFY coloursChanged)
    Q_PROPERTY(qreal hotThreshold READ hotThreshold WRITE setHotThreshold NOTIFY coloursChanged)
    Q_PROPERTY(bool peakHold READ peakHold WRITE setPeakHold NOTIFY ballisticsChanged)
    Q_PROPERTY(bool animated READ animated WRITE setAnimated NOTIFY ballisticsChanged)
    Q_PROPERTY(qreal attack READ attack WRITE setAttack NOTIFY ballisticsChanged)
    Q_PROPERTY(qreal decay READ decay WRITE setDecay NOTIFY ballisticsChanged)
    Q_PROPERTY(qreal peakHoldTime READ peakHoldTime WRITE setPeakHoldTime NOTIFY ballisticsChanged)
    Q_PROPERTY(qreal peakFall READ peakFall WRITE setPeakFall NOTIFY ballisticsChanged)
    Q_PROPERTY(bool settled READ settled NOTIFY settledChanged)
    // Diagnostics for tests and the idle-cost probe: ballistics steps and
    // scene-graph updates since creation. Deliberately without NOTIFY so a
    // probe can read them without every frame emitting into QML.
    Q_PROPERTY(int frames READ frames)
    Q_PROPERTY(int paints READ paints)

public:
    enum Direction {
        Up = 0,
        Down,
        Left,
        Right
    };
    Q_ENUM(Direction)

    explicit SpectrumMeter(QQuickItem* parent = nullptr);

    [[nodiscard]] QList<double> values() const { return m_values; }
    void setValues(const QList<double>& values);
    [[nodiscard]] int bands() const { return m_bands; }
    void setBands(int bands);
    [[nodiscard]] int sliceStart() const { return m_sliceStart; }
    void setSliceStart(int v);
    [[nodiscard]] int sliceLength() const { return m_sliceLength; }
    void setSliceLength(int v);
    [[nodiscard]] bool active() const { return m_active; }
    void setActive(bool active);

    [[nodiscard]] Direction direction() const { return m_direction; }
    void setDirection(Direction dir);
    [[nodiscard]] bool reversed() const { return m_reversed; }
    void setReversed(bool r);
    [[nodiscard]] qreal segment() const { return m_segment; }
    void setSegment(qreal v);
    [[nodiscard]] qreal segmentGap() const { return m_segmentGap; }
    void setSegmentGap(qreal v);
    [[nodiscard]] qreal bandGap() const { return m_bandGap; }
    void setBandGap(qreal v);
    [[nodiscard]] qreal peakThickness() const { return m_peakThickness; }
    void setPeakThickness(qreal v);

    [[nodiscard]] QColor onColor() const { return m_onColor; }
    void setOnColor(const QColor& c);
    [[nodiscard]] QColor hotColor() const { return m_hotColor; }
    void setHotColor(const QColor& c);
    [[nodiscard]] QColor offColor() const { return m_offColor; }
    void setOffColor(const QColor& c);
    [[nodiscard]] QColor peakColor() const { return m_peakColor; }
    void setPeakColor(const QColor& c);
    [[nodiscard]] qreal hotThreshold() const { return m_hotThreshold; }
    void setHotThreshold(qreal v);

    [[nodiscard]] bool peakHold() const { return m_params.peakHold; }
    void setPeakHold(bool v);
    [[nodiscard]] bool animated() const { return m_params.animated; }
    void setAnimated(bool v);
    [[nodiscard]] qreal attack() const { return m_params.attackMs; }
    void setAttack(qreal v);
    [[nodiscard]] qreal decay() const { return m_params.decayMs; }
    void setDecay(qreal v);
    [[nodiscard]] qreal peakHoldTime() const { return m_params.peakHoldMs; }
    void setPeakHoldTime(qreal v);
    [[nodiscard]] qreal peakFall() const { return m_params.peakFallPerSec; }
    void setPeakFall(qreal v);

    [[nodiscard]] bool settled() const { return m_settled; }
    [[nodiscard]] int frames() const { return m_frames; }
    [[nodiscard]] int paints() const { return m_paints; }

signals:
    void valuesChanged();
    void bandsChanged();
    void activeChanged();
    void geometryParamsChanged();
    void coloursChanged();
    void ballisticsChanged();
    void settledChanged();

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData* data) override;
    void itemChange(ItemChange change, const ItemChangeData& value) override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;

private:
    QList<double> m_values;
    int m_bands = 0;
    int m_sliceStart = 0;
    int m_sliceLength = 0;
    bool m_active = true;
    Direction m_direction = Up;
    bool m_reversed = false;
    qreal m_segment = 3;
    qreal m_segmentGap = 2;
    qreal m_bandGap = 2;
    qreal m_peakThickness = 1;
    QColor m_onColor = QColor(0x7f, 0xd6, 0x9a);
    QColor m_hotColor = QColor(0xe8, 0xa0, 0x3c);
    QColor m_offColor = Qt::transparent;
    QColor m_peakColor = QColor(0xe8, 0xa0, 0x3c);
    qreal m_hotThreshold = 0.85;

    spectrum::BallisticsParams m_params;
    spectrum::Ballistics m_engine;
    // Endless animation on the animation driver: runs only while awake.
    class FrameClock : public QAbstractAnimation {
    public:
        explicit FrameClock(SpectrumMeter* owner)
            : m_owner(owner) {}
        [[nodiscard]] int duration() const override { return -1; }

    protected:
        void updateCurrentTime(int currentTime) override;

    private:
        SpectrumMeter* m_owner;
    };

    FrameClock m_clock;
    int m_lastTick = -1;
    bool m_settled = true;
    int m_frames = 0;
    int m_paints = 0;

    void retarget();
    void applyParams();
    void wake();
    void sleep();
    void tick(int timeMs);
    void setSettled(bool settled);
    void repaint();
};

} // namespace hornero::internal
