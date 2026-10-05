"""Regression tests for versioned AUR source updates."""

from pathlib import Path

import pytest

from scripts.stamp_aur_package import REPOSITORY, stamp


@pytest.mark.parametrize(
    ("source", "tag", "expected_version"),
    [
        (f'source=("pkg::{REPOSITORY}#tag=v1.2.2")', "v1.2.3", "1.2.3"),
        (f'source=("pkg::{REPOSITORY}")', "v1.3.0-preview1", "1.3.0_preview1"),
    ],
)
def test_stamp_updates_version_and_existing_or_unpinned_source(
    tmp_path: Path, source: str, tag: str, expected_version: str
):
    pkgbuild = tmp_path / "PKGBUILD"
    pkgbuild.write_text(f"pkgver=1.2.2\n{source}\n", encoding="utf-8")

    stamp(pkgbuild, tag)

    result = pkgbuild.read_text(encoding="utf-8")
    assert f"pkgver={expected_version}" in result
    assert f"{REPOSITORY}#tag={tag}" in result
    assert result.count(REPOSITORY) == 1


@pytest.mark.parametrize(
    ("content", "tag"),
    [
        ("pkgver=1.2.2\n", "v1.2.3"),
        (f"pkgver=1.2.2\n{REPOSITORY}\n", "latest"),
    ],
)
def test_stamp_rejects_ambiguous_or_unpinned_input(tmp_path: Path, content: str, tag: str):
    pkgbuild = tmp_path / "PKGBUILD"
    pkgbuild.write_text(content, encoding="utf-8")

    with pytest.raises(ValueError):
        stamp(pkgbuild, tag)
