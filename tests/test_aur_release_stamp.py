"""Regression tests for versioned AUR source updates."""

from pathlib import Path

import pytest

from scripts.stamp_aur_package import REPOSITORY, stamp

WORKFLOW = Path(__file__).parents[1] / ".github/workflows/aur-publish.yml"
RELEASE_SHA = "a" * 40


def test_aur_workflow_only_listens_to_the_shell_package_namespace() -> None:
    workflow = WORKFLOW.read_text(encoding="utf-8")
    assert '"pkg/hornero-shell-v*"' in workflow
    assert '"v*"' not in workflow
    assert "RELEASE_SHA: ${{ github.sha }}" in workflow
    assert '"${RELEASE_SHA}"' in workflow
    assert workflow.index("Verify release commit is on main") < workflow.index(
        "Stamp pkgver and source commit"
    ) < workflow.index("Publish AUR package")


@pytest.mark.parametrize(
    ("source", "tag", "expected_version"),
    [
        (f'source=("pkg::{REPOSITORY}#tag=pkg/hornero-shell-v1.2.2")', "pkg/hornero-shell-v1.2.3", "1.2.3"),
        (f'source=("pkg::{REPOSITORY}")', "pkg/hornero-shell-v1.3.0_preview1", "1.3.0_preview1"),
    ],
)
def test_stamp_updates_version_and_existing_or_unpinned_source(
    tmp_path: Path, source: str, tag: str, expected_version: str
):
    pkgbuild = tmp_path / "PKGBUILD"
    pkgbuild.write_text(f"pkgver=1.2.2\n{source}\n", encoding="utf-8")

    stamp(pkgbuild, tag, RELEASE_SHA)

    result = pkgbuild.read_text(encoding="utf-8")
    assert f"pkgver={expected_version}" in result
    assert f"{REPOSITORY}#commit={RELEASE_SHA}" in result
    assert result.count(REPOSITORY) == 1


@pytest.mark.parametrize(
    ("content", "tag"),
    [
        ("pkgver=1.2.2\n", "v1.2.3"),
        (f"pkgver=1.2.2\n{REPOSITORY}\n", "latest"),
        (f"pkgver=1.2.2\n{REPOSITORY}\n", "v1.2.3"),
        (f"pkgver=1.2.2\n{REPOSITORY}\n", "pkg/hornero-shell-v1.2.3-preview1"),
    ],
)
def test_stamp_rejects_ambiguous_or_unpinned_input(tmp_path: Path, content: str, tag: str):
    pkgbuild = tmp_path / "PKGBUILD"
    pkgbuild.write_text(content, encoding="utf-8")

    with pytest.raises(ValueError):
        stamp(pkgbuild, tag, RELEASE_SHA)


@pytest.mark.parametrize("release_sha", ["", "a" * 39, "a" * 41, "g" * 40])
def test_stamp_rejects_invalid_release_sha(
    tmp_path: Path, release_sha: str
) -> None:
    pkgbuild = tmp_path / "PKGBUILD"
    pkgbuild.write_text(
        f"pkgver=1.2.2\nsource=(\"pkg::{REPOSITORY}\")\n", encoding="utf-8"
    )

    with pytest.raises(ValueError):
        stamp(pkgbuild, "pkg/hornero-shell-v1.2.3", release_sha)
