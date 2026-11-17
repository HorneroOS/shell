// SPDX-License-Identifier: GPL-3.0-only
//
// Statistics, deterministic quantiser and seed scoring (RFC 0002 §4.2–§4.4).
// Median cut (Heckbert, 1982) and Lloyd's k-means are textbook algorithms.
#include "hornero/chromatic/analysis.hpp"

#include "hornero/chromatic/json.hpp"
#include "hornero/chromatic/request.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <numbers>
#include <numeric>

namespace hornero::chromatic {

namespace {

constexpr int kWorkSide = 256;
constexpr int kMaxClusters = 16;
constexpr int kLloydIterations = 8;
constexpr double kMergeDistance = 0.02;
constexpr double kBandFraction = 0.08;
constexpr int kHueBins = 36;
// RFC §4.4 says s >= 0.005, but its own corpus requires a 0.3 % dot to win;
// after the 256 px box filter such a dot keeps ~0.23 % in its core cluster.
// 0.002 satisfies both intents (tiny saturated objects still seed).
constexpr double kMinSeedShare = 0.002;

struct Px {
    Oklab lab;
    double C;
    double h;
    double Y; // WCAG relative luminance
    double w; // frame-normalised × band weight
    int bin;  // 5-bit sRGB grid index
};

struct Bin {
    double w = 0;
    Oklab sum;
    [[nodiscard]] Oklab mean() const { return { sum.L / w, sum.a / w, sum.b / w }; }
};

struct Point {
    Oklab lab;
    double w;
};

double axis(const Oklab& c, int k) {
    return k == 0 ? c.L : (k == 1 ? c.a : c.b);
}

double weightedPercentile(std::vector<std::pair<double, double>>& vw, double q) {
    // vw: (value, weight); stable order → deterministic.
    if (vw.empty())
        return 0.0;
    std::stable_sort(vw.begin(), vw.end(), [](const auto& x, const auto& y) { return x.first < y.first; });
    double total = 0;
    for (const auto& p : vw)
        total += p.second;
    const double target = q * total;
    double run = 0;
    for (const auto& p : vw) {
        run += p.second;
        if (run >= target)
            return p.first;
    }
    return vw.back().first;
}

// Median cut over histogram points; returns box memberships as index lists.
std::vector<std::vector<std::size_t>> medianCut(const std::vector<Point>& pts) {
    std::vector<std::vector<std::size_t>> boxes;
    if (pts.empty())
        return boxes;
    std::vector<std::size_t> all(pts.size());
    std::iota(all.begin(), all.end(), std::size_t { 0 });
    boxes.push_back(std::move(all));
    const auto sse = [&pts](const std::vector<std::size_t>& box) {
        double w = 0;
        Oklab s;
        for (auto i : box) {
            w += pts[i].w;
            s.L += pts[i].lab.L * pts[i].w;
            s.a += pts[i].lab.a * pts[i].w;
            s.b += pts[i].lab.b * pts[i].w;
        }
        const Oklab m { s.L / w, s.a / w, s.b / w };
        double e = 0;
        for (auto i : box) {
            const double dL = pts[i].lab.L - m.L;
            const double da = pts[i].lab.a - m.a;
            const double db = pts[i].lab.b - m.b;
            e += pts[i].w * (dL * dL + da * da + db * db);
        }
        return e;
    };
    while (boxes.size() < static_cast<std::size_t>(kMaxClusters)) {
        std::size_t pick = boxes.size();
        double best = 0;
        for (std::size_t b = 0; b < boxes.size(); ++b) {
            if (boxes[b].size() < 2)
                continue;
            const double e = sse(boxes[b]);
            if (pick == boxes.size() || e > best) {
                best = e;
                pick = b;
            }
        }
        if (pick == boxes.size() || !(best > 0))
            break;
        auto& box = boxes[pick];
        int longest = 0;
        double extent = -1;
        for (int k = 0; k < 3; ++k) {
            double lo = axis(pts[box.front()].lab, k);
            double hi = lo;
            for (auto i : box) {
                lo = std::min(lo, axis(pts[i].lab, k));
                hi = std::max(hi, axis(pts[i].lab, k));
            }
            if (hi - lo > extent) {
                extent = hi - lo;
                longest = k;
            }
        }
        std::stable_sort(box.begin(), box.end(), [&](std::size_t x, std::size_t y) {
            const double ax = axis(pts[x].lab, longest);
            const double ay = axis(pts[y].lab, longest);
            return ax < ay || (!(ay < ax) && x < y);
        });
        double total = 0;
        for (auto i : box)
            total += pts[i].w;
        double run = 0;
        std::size_t cut = 1;
        for (std::size_t j = 0; j + 1 < box.size(); ++j) {
            run += pts[box[j]].w;
            cut = j + 1;
            if (run >= total / 2)
                break;
        }
        std::vector<std::size_t> right(box.begin() + static_cast<std::ptrdiff_t>(cut), box.end());
        box.resize(cut);
        std::sort(box.begin(), box.end());
        std::sort(right.begin(), right.end());
        boxes.push_back(std::move(right));
    }
    return boxes;
}

std::vector<Cluster> quantise(const std::vector<Point>& pts) {
    std::vector<Cluster> out;
    const auto boxes = medianCut(pts);
    std::vector<Oklab> centres;
    for (const auto& box : boxes) {
        double w = 0;
        Oklab s;
        for (auto i : box) {
            w += pts[i].w;
            s.L += pts[i].lab.L * pts[i].w;
            s.a += pts[i].lab.a * pts[i].w;
            s.b += pts[i].lab.b * pts[i].w;
        }
        if (w > 0)
            centres.push_back({ s.L / w, s.a / w, s.b / w });
    }
    std::vector<double> weights(centres.size(), 0.0);
    for (int it = 0; it < kLloydIterations && !centres.empty(); ++it) {
        std::vector<Oklab> sums(centres.size());
        std::fill(weights.begin(), weights.end(), 0.0);
        weights.resize(centres.size(), 0.0);
        for (const auto& p : pts) {
            std::size_t best = 0;
            double bd = 0;
            for (std::size_t c = 0; c < centres.size(); ++c) {
                const double d = std::pow(p.lab.L - centres[c].L, 2) + std::pow(p.lab.a - centres[c].a, 2)
                    + std::pow(p.lab.b - centres[c].b, 2);
                if (c == 0 || d < bd) {
                    bd = d;
                    best = c;
                }
            }
            weights[best] += p.w;
            sums[best].L += p.lab.L * p.w;
            sums[best].a += p.lab.a * p.w;
            sums[best].b += p.lab.b * p.w;
        }
        std::vector<Oklab> next;
        std::vector<double> nextW;
        for (std::size_t c = 0; c < centres.size(); ++c) {
            if (!(weights[c] > 0))
                continue; // drop empty clusters
            next.push_back({ sums[c].L / weights[c], sums[c].a / weights[c], sums[c].b / weights[c] });
            nextW.push_back(weights[c]);
        }
        centres = std::move(next);
        weights = std::move(nextW);
    }
    // Merge clusters closer than ΔEOK 0.02 (lowest index absorbs).
    bool merged = true;
    while (merged) {
        merged = false;
        for (std::size_t i = 0; i < centres.size() && !merged; ++i) {
            for (std::size_t j = i + 1; j < centres.size() && !merged; ++j) {
                if (deltaEOK(centres[i], centres[j]) < kMergeDistance) {
                    const double w = weights[i] + weights[j];
                    centres[i] = { (centres[i].L * weights[i] + centres[j].L * weights[j]) / w,
                        (centres[i].a * weights[i] + centres[j].a * weights[j]) / w,
                        (centres[i].b * weights[i] + centres[j].b * weights[j]) / w };
                    weights[i] = w;
                    centres.erase(centres.begin() + static_cast<std::ptrdiff_t>(j));
                    weights.erase(weights.begin() + static_cast<std::ptrdiff_t>(j));
                    merged = true;
                }
            }
        }
    }
    double total = 0;
    for (double w : weights)
        total += w;
    for (std::size_t c = 0; c < centres.size(); ++c)
        out.push_back({ centres[c], total > 0 ? weights[c] / total : 0.0 });
    std::stable_sort(out.begin(), out.end(), [](const Cluster& x, const Cluster& y) {
        if (x.share > y.share || x.share < y.share)
            return x.share > y.share;
        if (x.lab.L < y.lab.L || x.lab.L > y.lab.L)
            return x.lab.L < y.lab.L;
        if (x.lab.a < y.lab.a || x.lab.a > y.lab.a)
            return x.lab.a < y.lab.a;
        return x.lab.b < y.lab.b;
    });
    if (out.size() > static_cast<std::size_t>(kMaxClusters))
        out.resize(static_cast<std::size_t>(kMaxClusters));
    return out;
}

} // namespace

QString Analysis::digest() const {
    return QStringLiteral("sha256:") + sha256Hex(compact(toCacheJson(*this)));
}

Analysis analyse(const FrameSet& set) {
    Analysis a;
    a.algorithm = kAlgorithm;
    a.kind = set.kind;
    a.note = set.note;

    std::vector<Px> px;
    std::vector<double> detailPerFrame;
    std::vector<double> gridSum(static_cast<std::size_t>(kGridCols * kGridRows), 0.0);
    std::vector<double> gridSq(gridSum.size(), 0.0);
    std::vector<double> gridW(gridSum.size(), 0.0);
    double topW = 0, topS = 0, topSq = 0, botW = 0, botS = 0, botSq = 0;
    bool first = true;
    const double frameCount = static_cast<double>(std::max<qsizetype>(1, set.frames.size()));

    for (const QImage& frame : set.frames) {
        const LinearImage lin = downscaleLinear(frame, kWorkSide);
        const int w = lin.width;
        const int h = lin.height;
        std::size_t valid = 0;
        for (auto v : lin.valid)
            valid += v;
        if (valid == 0)
            continue;
        const int band = std::max(1, static_cast<int>(std::lround(h * kBandFraction)));
        std::vector<double> Lgrid(lin.valid.size(), 0.0);
        const double frameW = 1.0 / (static_cast<double>(valid) * frameCount);
        for (int y = 0; y < h; ++y) {
            const bool inTop = y < band;
            const bool inBottom = y >= h - band;
            const double bw = (inTop || inBottom) ? 2.0 : 1.0;
            for (int x = 0; x < w; ++x) {
                const std::size_t c = static_cast<std::size_t>(y) * static_cast<std::size_t>(w) + static_cast<std::size_t>(x);
                if (!lin.valid[c])
                    continue;
                const LinearRgb rgb { lin.rgb[c * 3], lin.rgb[c * 3 + 1], lin.rgb[c * 3 + 2] };
                const Oklab lab = toOklab(rgb);
                const Oklch lch = toOklch(lab);
                const double Y = 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b;
                const Srgb enc = toSrgb(rgb);
                const auto q = [](double v) {
                    return std::min(31, std::max(0, static_cast<int>(std::floor(std::min(1.0, std::max(0.0, v)) * 31.0 + 0.5))));
                };
                const int bin = (q(enc.r) << 10) | (q(enc.g) << 5) | q(enc.b);
                px.push_back({ lab, lch.C, lch.h, Y, frameW * bw, bin });
                Lgrid[c] = lab.L;
                if (first) {
                    a.Lmin = lab.L;
                    a.Lmax = lab.L;
                    first = false;
                } else {
                    a.Lmin = std::min(a.Lmin, lab.L);
                    a.Lmax = std::max(a.Lmax, lab.L);
                }
                if (inTop) {
                    topW += frameW;
                    topS += frameW * lab.L;
                    topSq += frameW * lab.L * lab.L;
                }
                if (inBottom) {
                    botW += frameW;
                    botS += frameW * lab.L;
                    botSq += frameW * lab.L * lab.L;
                }
                const auto gx = static_cast<std::size_t>((static_cast<qint64>(x) * kGridCols) / w);
                const auto gy = static_cast<std::size_t>((static_cast<qint64>(y) * kGridRows) / h);
                const std::size_t g = gy * static_cast<std::size_t>(kGridCols) + gx;
                gridSum[g] += frameW * Y;
                gridSq[g] += frameW * Y * Y;
                gridW[g] += frameW;
            }
        }
        // Detail: mean |4-neighbour Laplacian| of L where all five are valid.
        double lap = 0;
        std::size_t n = 0;
        for (int y = 1; y + 1 < h; ++y) {
            for (int x = 1; x + 1 < w; ++x) {
                const auto at = [&](int xx, int yy) {
                    return static_cast<std::size_t>(yy) * static_cast<std::size_t>(w) + static_cast<std::size_t>(xx);
                };
                const std::size_t c = at(x, y);
                if (!lin.valid[c] || !lin.valid[at(x - 1, y)] || !lin.valid[at(x + 1, y)] || !lin.valid[at(x, y - 1)]
                    || !lin.valid[at(x, y + 1)])
                    continue;
                lap += std::abs(4.0 * Lgrid[c] - Lgrid[at(x - 1, y)] - Lgrid[at(x + 1, y)] - Lgrid[at(x, y - 1)]
                    - Lgrid[at(x, y + 1)]);
                ++n;
            }
        }
        detailPerFrame.push_back(n ? lap / static_cast<double>(n) : 0.0);
    }

    if (px.empty()) {
        a.achromatic = true;
        a.lumaGrid = QByteArray(kGridCols * kGridRows * 2, '\0');
        return a;
    }

    // --- lightness and chroma statistics (band-weighted) ---
    double W = 0, sL = 0, sC = 0;
    for (const auto& p : px) {
        W += p.w;
        sL += p.w * p.lab.L;
        sC += p.w * p.C;
    }
    a.meanL = sL / W;
    a.meanC = sC / W;
    double var = 0;
    for (const auto& p : px)
        var += p.w * (p.lab.L - a.meanL) * (p.lab.L - a.meanL);
    a.stdL = std::sqrt(var / W);
    {
        std::vector<std::pair<double, double>> Ls;
        std::vector<std::pair<double, double>> Cs;
        std::vector<std::pair<double, double>> brightCs;
        Ls.reserve(px.size());
        Cs.reserve(px.size());
        for (const auto& p : px) {
            Ls.emplace_back(p.lab.L, p.w);
            Cs.emplace_back(p.C, p.w);
            if (p.lab.L > 0.6)
                brightCs.emplace_back(p.C, p.w);
        }
        a.L5 = weightedPercentile(Ls, 0.05);
        a.L50 = weightedPercentile(Ls, 0.50);
        a.L95 = weightedPercentile(Ls, 0.95);
        a.C90 = weightedPercentile(Cs, 0.90);
        a.C95 = weightedPercentile(Cs, 0.95);
        a.brightC95 = weightedPercentile(brightCs, 0.95);
    }
    a.top = topW > 0 ? BandStats { topS / topW, std::sqrt(std::max(0.0, topSq / topW - std::pow(topS / topW, 2))) }
                     : BandStats { a.meanL, a.stdL };
    a.bottom = botW > 0 ? BandStats { botS / botW, std::sqrt(std::max(0.0, botSq / botW - std::pow(botS / botW, 2))) }
                        : BandStats { a.meanL, a.stdL };
    a.detail = detailPerFrame.empty()
        ? 0.0
        : std::accumulate(detailPerFrame.begin(), detailPerFrame.end(), 0.0) / static_cast<double>(detailPerFrame.size());

    // Hue histogram (36 bins weighted by chroma) and its entropy in bits.
    std::array<double, kHueBins> hist {};
    double histTotal = 0;
    double weakA = 0, weakB = 0, weakMass = 0;
    for (const auto& p : px) {
        if (p.C <= 0.005)
            continue;
        const auto b = static_cast<std::size_t>(std::min(kHueBins - 1, static_cast<int>(p.h / (360.0 / kHueBins))));
        hist[b] += p.w * p.C;
        histTotal += p.w * p.C;
        weakA += p.w * p.lab.a;
        weakB += p.w * p.lab.b;
        weakMass += p.w * p.C;
    }
    if (histTotal > 0) {
        for (double v : hist)
            if (v > 0)
                a.hueEntropy -= (v / histTotal) * std::log2(v / histTotal);
    }
    if (weakMass > 0 && std::hypot(weakA, weakB) / weakMass > 0.2)
        a.weakHue = wrapHue(std::atan2(weakB, weakA) * 180.0 / std::numbers::pi);

    // Luminance grid for the Cockpit Clear sampler.
    a.lumaGrid.resize(kGridCols * kGridRows * 2);
    for (std::size_t g = 0; g < gridSum.size(); ++g) {
        double mean = 0, dev = 0;
        if (gridW[g] > 0) {
            mean = gridSum[g] / gridW[g];
            dev = std::sqrt(std::max(0.0, gridSq[g] / gridW[g] - mean * mean));
        }
        a.lumaGrid[static_cast<qsizetype>(g * 2)] = static_cast<char>(static_cast<std::uint8_t>(std::lround(std::min(1.0, mean) * 255.0)));
        a.lumaGrid[static_cast<qsizetype>(g * 2 + 1)] = static_cast<char>(static_cast<std::uint8_t>(std::lround(std::min(1.0, dev) * 255.0)));
    }

    // --- quantisation over the 5-bit sRGB histogram ---
    std::vector<Bin> bins(32768);
    for (const auto& p : px) {
        Bin& b = bins[static_cast<std::size_t>(p.bin)];
        b.w += p.w;
        b.sum.L += p.w * p.lab.L;
        b.sum.a += p.w * p.lab.a;
        b.sum.b += p.w * p.lab.b;
    }
    std::vector<Point> pts;
    for (const auto& b : bins)
        if (b.w > 0)
            pts.push_back({ b.mean(), b.w });
    const std::vector<Cluster> clusters = quantise(pts);
    a.clusters = QList<Cluster>(clusters.begin(), clusters.end());

    // --- seed scoring (§4.4) ---
    double chromaMass = 0;
    for (const auto& c : clusters)
        chromaMass += c.share * toOklch(c.lab).C;
    struct Scored {
        std::size_t index;
        Seed seed;
    };
    std::vector<Scored> scored;
    for (std::size_t i = 0; i < clusters.size(); ++i) {
        const Cluster& c = clusters[i];
        const Oklch lch = toOklch(c.lab);
        double near = 0;
        for (const auto& o : clusters) {
            const Oklch ol = toOklch(o.lab);
            if (std::abs(hueDiff(ol.h, lch.h)) <= 15.0)
                near += o.share * ol.C;
        }
        const double neighbourhood = chromaMass > 0 ? near / chromaMass : 0.0;
        double score = 0.70 * std::sqrt(c.share) * 10.0 + 0.30 * std::min(lch.C, 0.20) / 0.20 * 10.0
            + 0.10 * neighbourhood;
        if (lch.C < 0.02)
            score -= 4.0;
        if (lch.L < 0.15 || lch.L > 0.95)
            score -= 2.0;
        if (lch.h >= 90.0 && lch.h <= 115.0 && lch.L < 0.60 && lch.C > 0.04)
            score -= 1.5;
        if (c.share < kMinSeedShare)
            continue;
        scored.push_back({ i, Seed { toHex(lch), lch, c.share, score } });
    }
    std::stable_sort(scored.begin(), scored.end(), [](const Scored& x, const Scored& y) {
        if (x.seed.score > y.seed.score || x.seed.score < y.seed.score)
            return x.seed.score > y.seed.score;
        return x.index < y.index;
    });
    for (std::size_t i = 0; i < scored.size() && i < 5; ++i)
        a.seeds.append(scored[i].seed);

    for (const auto& c : clusters) {
        const Oklch lch = toOklch(c.lab);
        if (lch.C >= 0.01) {
            a.neutralHue = lch.h;
            break;
        }
    }
    if (!a.neutralHue && !a.seeds.isEmpty())
        a.neutralHue = a.seeds.first().lch.h;
    a.achromatic = a.C90 < 0.025;
    return a;
}

} // namespace hornero::chromatic
