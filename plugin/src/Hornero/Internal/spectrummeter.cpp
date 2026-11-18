#include "spectrummeter.hpp"

#include <QQuickWindow>
#include <QSGNode>
#include <QSGRectangleNode>
#include <algorithm>
#include <cmath>
#include <vector>

namespace hornero::internal {

namespace {

// Root node that owns a pool of rectangle children, reused frame to frame.
class MeterNode : public QSGNode {
public:
    std::vector<QSGRectangleNode*> rects;
};

struct Fill {
    QRectF rect;
    QColor colour;
};

bool visibleColour(const QColor& c) {
    return c.isValid() && c.alpha() > 0;
}

} // namespace

void SpectrumMeter::FrameClock::updateCurrentTime(int currentTime) {
    m_owner->tick(currentTime);
}

SpectrumMeter::SpectrumMeter(QQuickItem* parent)
    : QQuickItem(parent)
    , m_clock(this) {
    setFlag(ItemHasContents, true);
    m_engine.setParams(m_params);
}

// --- inputs -----------------------------------------------------------------

void SpectrumMeter::setValues(const QList<double>& values) {
    if (values == m_values) {
        return;
    }
    m_values = values;
    emit valuesChanged();
    retarget();
}

void SpectrumMeter::setBands(int bands) {
    bands = std::clamp(bands, 0, 256);
    if (bands == m_bands) {
        return;
    }
    m_bands = bands;
    emit bandsChanged();
    retarget();
}

void SpectrumMeter::setSliceStart(int v) {
    v = std::max(0, v);
    if (v == m_sliceStart) {
        return;
    }
    m_sliceStart = v;
    emit bandsChanged();
    retarget();
}

void SpectrumMeter::setSliceLength(int v) {
    v = std::max(0, v);
    if (v == m_sliceLength) {
        return;
    }
    m_sliceLength = v;
    emit bandsChanged();
    retarget();
}

void SpectrumMeter::setActive(bool active) {
    if (active == m_active) {
        return;
    }
    m_active = active;
    emit activeChanged();
    retarget();
}

void SpectrumMeter::retarget() {
    const auto total = static_cast<std::size_t>(m_values.size());
    const std::size_t from = std::min(static_cast<std::size_t>(m_sliceStart), total);
    const std::size_t len = m_sliceLength > 0 ? std::min(static_cast<std::size_t>(m_sliceLength), total - from) : total - from;
    const std::span<const double> source(m_values.constData() + from, len);
    const int n = m_bands > 0 ? m_bands : static_cast<int>(len);
    std::vector<double> targets = spectrum::resample(source, n);
    if (!m_active) {
        std::fill(targets.begin(), targets.end(), 0.0);
    }
    const int before = m_engine.bandCount();
    const bool moving = m_engine.setTargets(targets);
    if (!m_params.animated) {
        // Reduced motion: the engine already jumped; paint once, no clock.
        repaint();
        return;
    }
    if (moving) {
        wake();
    } else if (before != m_engine.bandCount()) {
        repaint();
    }
}

// --- frame driver ------------------------------------------------------------

void SpectrumMeter::wake() {
    setSettled(false);
    if (!window() || !isVisible()) {
        return; // resumes from itemChange() once shown
    }
    if (m_clock.state() == QAbstractAnimation::Running) {
        return; // already ticking: the next tick picks the new targets up
    }
    m_lastTick = -1;
    m_clock.start();
    repaint();
}

void SpectrumMeter::sleep() {
    m_clock.stop();
}

void SpectrumMeter::tick(int timeMs) {
    // The clock is an endless animation on the window's animation driver,
    // so it is vsync paced on a real display (like FrameAnimation) and new
    // values (cava runs at ~86 Hz) never add frames of their own. Clamp the
    // step so a stall does not teleport the levels.
    const double dt = m_lastTick < 0 ? 0.0 : std::clamp(static_cast<double>(timeMs - m_lastTick), 0.0, 100.0);
    m_lastTick = timeMs;
    const bool moving = m_engine.step(dt);
    ++m_frames;
    repaint();
    if (!moving) {
        sleep();
        setSettled(true);
    }
}

void SpectrumMeter::setSettled(bool settled) {
    if (settled != m_settled) {
        m_settled = settled;
        emit settledChanged();
    }
}

void SpectrumMeter::repaint() {
    update();
}

void SpectrumMeter::itemChange(ItemChange change, const ItemChangeData& value) {
    if (change == ItemSceneChange) {
        sleep();
        if (value.window && !m_engine.settled()) {
            wake();
        }
    } else if (change == ItemVisibleHasChanged) {
        if (!value.boolValue) {
            sleep();
        } else if (!m_engine.settled()) {
            wake();
        } else {
            repaint();
        }
    }
    QQuickItem::itemChange(change, value);
}

void SpectrumMeter::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) {
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size()) {
        repaint();
    }
}

// --- parameters --------------------------------------------------------------

#define HORNERO_SETTER(Setter, member, signal, Type)                                                                   \
    void SpectrumMeter::Setter(Type v) {                                                                               \
        if (member == v) {                                                                                             \
            return;                                                                                                    \
        }                                                                                                              \
        member = v;                                                                                                    \
        emit signal();                                                                                                 \
        repaint();                                                                                                     \
    }

void SpectrumMeter::setDirection(Direction dir) {
    if (dir == m_direction) {
        return;
    }
    m_direction = dir;
    emit geometryParamsChanged();
    repaint();
}

HORNERO_SETTER(setReversed, m_reversed, geometryParamsChanged, bool)
HORNERO_SETTER(setOnColor, m_onColor, coloursChanged, const QColor&)
HORNERO_SETTER(setHotColor, m_hotColor, coloursChanged, const QColor&)
HORNERO_SETTER(setOffColor, m_offColor, coloursChanged, const QColor&)
HORNERO_SETTER(setPeakColor, m_peakColor, coloursChanged, const QColor&)

#undef HORNERO_SETTER

namespace {

bool sameReal(qreal a, qreal b) {
    return std::abs(a - b) < 1e-9;
}

} // namespace

void SpectrumMeter::setSegment(qreal v) {
    v = std::max<qreal>(0, v);
    if (sameReal(v, m_segment)) {
        return;
    }
    m_segment = v;
    emit geometryParamsChanged();
    repaint();
}

void SpectrumMeter::setSegmentGap(qreal v) {
    v = std::max<qreal>(0, v);
    if (sameReal(v, m_segmentGap)) {
        return;
    }
    m_segmentGap = v;
    emit geometryParamsChanged();
    repaint();
}

void SpectrumMeter::setBandGap(qreal v) {
    v = std::max<qreal>(0, v);
    if (sameReal(v, m_bandGap)) {
        return;
    }
    m_bandGap = v;
    emit geometryParamsChanged();
    repaint();
}

void SpectrumMeter::setPeakThickness(qreal v) {
    v = std::max<qreal>(0, v);
    if (sameReal(v, m_peakThickness)) {
        return;
    }
    m_peakThickness = v;
    emit geometryParamsChanged();
    repaint();
}

void SpectrumMeter::setHotThreshold(qreal v) {
    if (sameReal(v, m_hotThreshold)) {
        return;
    }
    m_hotThreshold = v;
    emit coloursChanged();
    repaint();
}

void SpectrumMeter::applyParams() {
    m_engine.setParams(m_params);
    emit ballisticsChanged();
    if (!m_params.animated) {
        sleep();
        setSettled(true);
        repaint();
    } else if (!m_engine.settled()) {
        wake();
    }
}

void SpectrumMeter::setPeakHold(bool v) {
    if (v == m_params.peakHold) {
        return;
    }
    m_params.peakHold = v;
    applyParams();
}

void SpectrumMeter::setAnimated(bool v) {
    if (v == m_params.animated) {
        return;
    }
    m_params.animated = v;
    applyParams();
}

void SpectrumMeter::setAttack(qreal v) {
    if (sameReal(v, m_params.attackMs)) {
        return;
    }
    m_params.attackMs = v;
    applyParams();
}

void SpectrumMeter::setDecay(qreal v) {
    if (sameReal(v, m_params.decayMs)) {
        return;
    }
    m_params.decayMs = v;
    applyParams();
}

void SpectrumMeter::setPeakHoldTime(qreal v) {
    if (sameReal(v, m_params.peakHoldMs)) {
        return;
    }
    m_params.peakHoldMs = v;
    applyParams();
}

void SpectrumMeter::setPeakFall(qreal v) {
    if (sameReal(v, m_params.peakFallPerSec)) {
        return;
    }
    m_params.peakFallPerSec = v;
    applyParams();
}

// --- painting ----------------------------------------------------------------

QSGNode* SpectrumMeter::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) {
    auto* node = static_cast<MeterNode*>(oldNode);
    QQuickWindow* win = window();
    const qreal w = width();
    const qreal h = height();
    const int n = m_engine.bandCount();
    if (!win || n == 0 || w <= 0 || h <= 0) {
        delete node;
        return nullptr;
    }
    if (!node) {
        node = new MeterNode;
    }
    ++m_paints;

    const bool alongX = m_direction == Up || m_direction == Down; // bands laid out along x
    const qreal across = alongX ? w : h;                          // room for the bands
    const qreal length = alongX ? h : w;                          // room for one band to grow
    const qreal bandGap = n > 1 ? std::min(m_bandGap, across / (2.0 * n)) : 0;
    const qreal band = std::max<qreal>(1, (across - bandGap * (n - 1)) / n);
    const bool segmented = m_segment > 0;
    const qreal step = m_segment + m_segmentGap;
    const int segments = segmented ? std::max(1, static_cast<int>(std::floor((length + m_segmentGap) / step))) : 0;

    // Map (band offset b, growth offset a, band thickness bw, growth la) to item space.
    auto place = [&](qreal b, qreal a, qreal bw, qreal la) -> QRectF {
        switch (m_direction) {
        case Up:
            return { b, h - a - la, bw, la };
        case Down:
            return { b, a, bw, la };
        case Right:
            return { a, b, la, bw };
        case Left:
            return { w - a - la, b, la, bw };
        }
        return {};
    };

    // One stable node per slot (band x segment, plus the band's peak tick),
    // so a band that changes only dirties its own nodes. Unused slots keep
    // an empty rect instead of being removed, which would shift every later
    // node and force the renderer to redraw the whole meter.
    const std::size_t perBand = segmented ? static_cast<std::size_t>(segments) + 1 : 3;
    std::vector<Fill> fills(static_cast<std::size_t>(n) * perBand);
    const auto& levels = m_engine.levels();
    const auto& peaks = m_engine.peaks();
    const bool drawOff = visibleColour(m_offColor);
    const bool drawPeak = m_params.peakHold && m_peakThickness > 0 && visibleColour(m_peakColor);

    for (int i = 0; i < n; ++i) {
        const int slot = m_reversed ? n - 1 - i : i;
        const qreal b = slot * (band + bandGap);
        const double level = levels[static_cast<std::size_t>(i)];
        const double peak = peaks[static_cast<std::size_t>(i)];
        Fill* f = &fills[static_cast<std::size_t>(i) * perBand];
        if (segmented) {
            const int lit = static_cast<int>(std::lround(level * segments));
            for (int s = 0; s < segments; ++s) {
                const bool on = s < lit;
                if (!on && !drawOff) {
                    continue;
                }
                const bool hot = (static_cast<double>(s + 1) / segments) > m_hotThreshold;
                f[s] = { place(b, s * step, band, m_segment), on ? (hot ? m_hotColor : m_onColor) : m_offColor };
            }
            if (drawPeak) {
                const int top = static_cast<int>(std::ceil(peak * segments - 1e-6));
                if (top > 0) {
                    // The tick sits on the outer edge of the gap above the
                    // segment the peak reached, pixel aligned so it stays crisp.
                    const qreal a = std::clamp(std::round(top * step - m_peakThickness), 0.0, length - m_peakThickness);
                    f[segments] = { place(b, a, band, m_peakThickness), m_peakColor };
                }
            }
        } else {
            if (drawOff) {
                f[0] = { place(b, 0, band, length), m_offColor };
            }
            const qreal la = std::round(level * length);
            if (la >= 1) {
                f[1] = { place(b, 0, band, la), level > m_hotThreshold ? m_hotColor : m_onColor };
            }
            if (drawPeak && peak * length >= 0.5) {
                const qreal a = std::clamp(std::round(peak * length - m_peakThickness), 0.0, length - m_peakThickness);
                f[2] = { place(b, a, band, m_peakThickness), m_peakColor };
            }
        }
    }

    // The pool only changes size when the band or segment count does.
    while (node->rects.size() < fills.size()) {
        QSGRectangleNode* r = win->createRectangleNode();
        r->setRect(QRectF());
        node->appendChildNode(r);
        node->rects.push_back(r);
    }
    while (node->rects.size() > fills.size()) {
        QSGRectangleNode* r = node->rects.back();
        node->rects.pop_back();
        node->removeChildNode(r);
        delete r;
    }
    for (std::size_t i = 0; i < fills.size(); ++i) {
        QSGRectangleNode* r = node->rects[i];
        if (r->rect() != fills[i].rect) {
            r->setRect(fills[i].rect);
        }
        if (!fills[i].rect.isEmpty() && r->color() != fills[i].colour) {
            r->setColor(fills[i].colour);
        }
    }
    return node;
}

} // namespace hornero::internal
