"""RFC 0002 §14 performance budgets; CI fails at 3x (contract §8).

Needs HORNERO_CHROMATIC_BENCH (built chromatic-bench) and the corpus
generator; draws 4K/8K bench sources into the scratch tree.
"""
import json
import os
import statistics
import subprocess
import sys
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent / "chromatic"))
import harness  # noqa: E402

FACTOR = float(os.environ.get("CHROMATIC_PERF_FACTOR", "3"))
BUDGET_MS = {"decodeAnalyse4kJpeg": 60, "decodeAnalyse4kPng": 150, "synthesise": 2}
HELPER_CACHE_HIT_MS = 20
MEMORY_MB = {"bench-4k.png": 96, "bench-8k.png": 220}


@pytest.fixture(scope="module")
def bench_dir():
    bench = os.environ.get("HORNERO_CHROMATIC_BENCH")
    gen = os.environ.get("HORNERO_CHROMATIC_CORPUS")
    if not bench or not gen:
        pytest.skip("HORNERO_CHROMATIC_BENCH / HORNERO_CHROMATIC_CORPUS not set")
    out = Path(harness.corpus()).parent / "bench"
    if not (out / "bench-8k.png").exists():
        env = dict(harness.isolated_env(), CHROMATIC_CORPUS_BENCH="1")
        subprocess.run([gen, str(out)], check=True, env=env, timeout=300)
    return bench, out


def test_bench_budgets(bench_dir):
    bench, out = bench_dir
    proc = subprocess.run([bench, str(out), "--iterations", "5"], capture_output=True, text=True,
                          env=harness.isolated_env(), timeout=600, check=True)
    timings = json.loads(proc.stdout)
    print(json.dumps(timings))
    over = {k: (timings[k], b * FACTOR) for k, b in BUDGET_MS.items() if timings.get(k, 0) > b * FACTOR}
    assert not over, f"over {FACTOR}x budget: {over}"


def test_helper_cache_hit_end_to_end(bench_dir, tmp_path):
    _, out = bench_dir
    src = str(out / "bench-4k.jpg")
    cache = tmp_path / "cache"
    harness.run("generate", "--source", src, cache=cache)
    samples = []
    for _ in range(7):
        start = time.perf_counter()
        rc, _, _ = harness.run("generate", "--source", src, cache=cache)
        samples.append((time.perf_counter() - start) * 1000)
        assert rc == 0
    median = statistics.median(samples)
    print(f"helper cache hit median {median:.1f} ms")
    assert median <= HELPER_CACHE_HIT_MS * FACTOR


@pytest.mark.parametrize("name", sorted(MEMORY_MB))
def test_helper_peak_memory(bench_dir, name):
    _, out = bench_dir
    cmd = [harness.helper(), "analyze", "--no-cache", "--source", str(out / name)]
    # A fresh interpreter isolates ru_maxrss of exactly this child.
    probe = ("import resource,subprocess,sys;subprocess.run(sys.argv[1:],check=True,stdout=subprocess.DEVNULL);"
             "print(resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)")
    rss_kb = int(subprocess.run([sys.executable, "-c", probe, *cmd], capture_output=True, text=True,
                                env=harness.isolated_env(), check=True, timeout=120).stdout)
    mb = rss_kb / 1024
    print(f"{name}: peak {mb:.1f} MB")
    assert mb <= MEMORY_MB[name] * FACTOR
