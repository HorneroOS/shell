// QtTest unit suite for the spectrum meter ballistics (ctest: spectrum-unit).
#include "spectrumballistics.hpp"

#include <QtTest>

#include <cmath>
#include <limits>
#include <vector>

using namespace hornero::internal::spectrum;

namespace {

// Steps at 60 Hz until `pred` holds; returns elapsed ms or -1 on timeout.
template <typename Pred> double runUntil(Ballistics& b, Pred pred, double limitMs = 10000) {
    double t = 0;
    while (t < limitMs) {
        if (pred()) {
            return t;
        }
        b.step(1000.0 / 60.0);
        t += 1000.0 / 60.0;
    }
    return -1;
}

std::vector<double> one(double v) {
    return { v };
}

} // namespace

class SpectrumUnit : public QObject {
    Q_OBJECT

private slots:
    void alphaIsExponential() {
        QCOMPARE(smoothingAlpha(0, 30), 0.0);
        QVERIFY(std::abs(smoothingAlpha(30, 30) - (1.0 - std::exp(-1.0))) < 1e-12);
        QCOMPARE(smoothingAlpha(16, 0), 1.0);
        QVERIFY(smoothingAlpha(1e6, 30) > 0.999999);
    }

    void attackIsFastAndDecayIsSlow() {
        Ballistics b;
        auto up = one(1.0);
        b.setTargets(up);
        const double rise = runUntil(b, [&] { return b.levels()[0] >= 0.9; });
        // tau 30 ms: 90 % after ~69 ms (a few frames).
        QVERIFY2(rise > 0 && rise <= 100, qPrintable(QString::number(rise)));

        auto down = one(0.0);
        b.setTargets(down);
        const double fall = runUntil(b, [&] { return b.levels()[0] <= 0.1; });
        // tau 300 ms: down to 10 % after ~690 ms.
        QVERIFY2(fall >= 600 && fall <= 800, qPrintable(QString::number(fall)));
        QVERIFY(fall > rise * 5);
    }

    void frameRateIndependent() {
        BallisticsParams p;
        p.peakHold = false;
        p.epsilon = 1e-6;
        Ballistics a;
        Ballistics c;
        a.setParams(p);
        c.setParams(p);
        auto t = one(0.8);
        a.setTargets(t);
        c.setTargets(t);
        a.step(32);
        c.step(16);
        c.step(16);
        QVERIFY(std::abs(a.levels()[0] - c.levels()[0]) < 1e-9);
    }

    void peakHoldsThenFallsAndNeverUndercutsLevel() {
        Ballistics b;
        auto loud = one(1.0);
        b.setTargets(loud);
        runUntil(b, [&] { return b.levels()[0] >= 1.0; });
        QCOMPARE(b.peaks()[0], 1.0);

        auto quiet = one(0.2);
        b.setTargets(quiet);
        // Inside the 600 ms hold the marker stays at full scale.
        double t = 0;
        while (t < 550) {
            b.step(10);
            t += 10;
            QCOMPARE(b.peaks()[0], 1.0);
            QVERIFY(b.peaks()[0] >= b.levels()[0]);
        }
        // After the hold it falls (1.6 / s) and lands on the live level.
        const double landed = runUntil(b, [&] { return b.peaks()[0] <= b.levels()[0]; });
        QVERIFY(landed > 0);
        QVERIFY(b.peaks()[0] >= b.levels()[0]);
    }

    void silenceSettlesAndStopsMoving() {
        Ballistics b;
        std::vector<double> music { 0.9, 0.5, 0.7, 0.2 };
        b.setTargets(music);
        for (int i = 0; i < 3; ++i) {
            b.step(16); // still rising toward the targets
        }
        QVERIFY(!b.settled());
        b.silence();
        const double t = runUntil(b, [&] { return b.settled(); });
        QVERIFY2(t > 0 && t < 4000, qPrintable(QString::number(t)));
        for (int i = 0; i < 4; ++i) {
            QCOMPARE(b.levels()[static_cast<std::size_t>(i)], 0.0);
            QCOMPARE(b.peaks()[static_cast<std::size_t>(i)], 0.0);
        }
        // Settled means step() reports no motion: the item can sleep.
        QVERIFY(!b.step(16));
        QVERIFY(!b.setTargets(std::vector<double>(4, 0.0)));
    }

    void steadyToneSettles() {
        Ballistics b;
        std::vector<double> tone { 0.6, 0.6 };
        b.setTargets(tone);
        QVERIFY(runUntil(b, [&] { return b.settled(); }) > 0);
        QCOMPARE(b.levels()[0], 0.6);
        QCOMPARE(b.peaks()[0], 0.6);
    }

    void reducedMotionJumps() {
        BallisticsParams p;
        p.animated = false;
        Ballistics b;
        b.setParams(p);
        std::vector<double> v { 0.3, 1.0 };
        b.setTargets(v);
        QCOMPARE(b.levels()[1], 1.0);
        QCOMPARE(b.peaks()[1], 1.0);
        QVERIFY(b.settled());
        QVERIFY(!b.step(16));
    }

    void inputsAreClamped() {
        Ballistics b;
        std::vector<double> bad { -1.0, 7.0, std::numeric_limits<double>::quiet_NaN(),
            std::numeric_limits<double>::infinity() };
        b.setTargets(bad);
        QCOMPARE(b.targets()[0], 0.0);
        QCOMPARE(b.targets()[1], 1.0);
        QCOMPARE(b.targets()[2], 0.0);
        QCOMPARE(b.targets()[3], 0.0);
    }

    void bandCountFollowsTargets() {
        Ballistics b;
        b.setTargets(std::vector<double>(8, 0.5));
        QCOMPARE(b.bandCount(), 8);
        b.setTargets(std::vector<double>(3, 0.5));
        QCOMPARE(b.bandCount(), 3);
    }

    void resampleShrinkKeepsLoudBands() {
        std::vector<double> in { 0.1, 0.9, 0.2, 0.3, 0.0, 0.4 };
        const auto out = resample(in, 3);
        QCOMPARE(out.size(), std::size_t(3));
        QCOMPARE(out[0], 0.9);
        QCOMPARE(out[1], 0.3);
        QCOMPARE(out[2], 0.4);
    }

    void resampleGrowInterpolates() {
        std::vector<double> in { 0.0, 1.0 };
        const auto out = resample(in, 5);
        QCOMPARE(out.size(), std::size_t(5));
        QCOMPARE(out[0], 0.0);
        QCOMPARE(out[2], 0.5);
        QCOMPARE(out[4], 1.0);
    }

    void resampleEdgeCases() {
        QVERIFY(resample(std::vector<double> { 0.5 }, 0).empty());
        QCOMPARE(resample(std::vector<double> {}, 4), std::vector<double>(4, 0.0));
        QCOMPARE(resample(std::vector<double> { 0.7 }, 3), std::vector<double>(3, 0.7));
        QCOMPARE(resample(std::vector<double> { 0.2, 2.0 }, 2), (std::vector<double> { 0.2, 1.0 }));
        // Non-integer ratio: every source band lands in some output band.
        std::vector<double> in(45, 0.0);
        in[44] = 1.0;
        QCOMPARE(resample(in, 16).back(), 1.0);
    }
};

QTEST_GUILESS_MAIN(SpectrumUnit)
#include "test_spectrum.moc"
