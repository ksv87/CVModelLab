"""Allowed-roots path resolution, traversal/symlink blocking, file browser."""

from __future__ import annotations

import os
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from cvmlab_server.core.paths import PathAccessError, PathResolver

from conftest import build_config


def _resolver(root: Path) -> PathResolver:
    return PathResolver(build_config(root))


def test_resolve_within_root_ok(dataset_root: Path) -> None:
    resolver = _resolver(dataset_root)
    resolved = resolver.resolve_within_root("datasets", "annotations.json")
    assert resolved.abs_path == str(
        (dataset_root / "datasets" / "annotations.json").resolve()
    )
    assert resolved.rel_path == "annotations.json"


def test_traversal_blocked(dataset_root: Path) -> None:
    resolver = _resolver(dataset_root)
    with pytest.raises(PathAccessError):
        resolver.resolve_within_root("datasets", "../experiments/predictions.json")


def test_absolute_in_browse_blocked(dataset_root: Path) -> None:
    resolver = _resolver(dataset_root)
    with pytest.raises(PathAccessError):
        resolver.resolve_within_root("datasets", "/etc/passwd")


def test_unknown_root(dataset_root: Path) -> None:
    resolver = _resolver(dataset_root)
    with pytest.raises(PathAccessError):
        resolver.resolve_within_root("nope", "x")


def test_resolve_absolute_outside_roots(dataset_root: Path, tmp_path: Path) -> None:
    resolver = _resolver(dataset_root)
    outside = tmp_path / "outside.json"
    outside.write_text("{}")
    with pytest.raises(PathAccessError):
        resolver.resolve_absolute(str(outside))


def test_symlink_escape_blocked(dataset_root: Path, tmp_path: Path) -> None:
    secret = tmp_path / "secret.txt"
    secret.write_text("top secret")
    link = dataset_root / "datasets" / "link.txt"
    try:
        os.symlink(secret, link)
    except (OSError, NotImplementedError):
        pytest.skip("symlinks not supported on this platform")
    resolver = _resolver(dataset_root)
    with pytest.raises(PathAccessError):
        resolver.resolve_within_root("datasets", "link.txt")


def test_browse_lists_entries(client: TestClient) -> None:
    roots = client.get("/api/roots").json()["roots"]
    assert any(r["id"] == "datasets" for r in roots)

    listing = client.get("/api/browse", params={"root_id": "datasets"}).json()
    names = {e["name"] for e in listing["entries"]}
    assert "annotations.json" in names
    assert "images" in names


def test_browse_json_filter(client: TestClient) -> None:
    listing = client.get(
        "/api/browse", params={"root_id": "datasets", "files": "json"}
    ).json()
    files = [e for e in listing["entries"] if e["kind"] == "file"]
    assert files and all(f["name"].endswith(".json") for f in files)
    # directories still listed
    assert any(e["kind"] == "directory" for e in listing["entries"])


def test_browse_traversal_rejected(client: TestClient) -> None:
    resp = client.get(
        "/api/browse", params={"root_id": "datasets", "path": "../experiments"}
    )
    assert resp.status_code == 400
