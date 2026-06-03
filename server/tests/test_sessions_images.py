"""Session open, image bytes/thumbnail, manifest validation."""

from __future__ import annotations

import json
from pathlib import Path

from fastapi.testclient import TestClient

from cvmlab_server.main import create_app

from conftest import build_config


def test_open_custom_session_summary(open_custom_session) -> None:
    body = open_custom_session
    assert body["summary"]["images"] == 2
    assert body["summary"]["categories"] == 2
    assert body["summary"]["annotations"] == 3
    assert body["summary"]["missing_images"] == 0
    assert body["session_id"]


def test_open_custom_paths_outside_roots_rejected(
    client: TestClient, tmp_path: Path
) -> None:
    outside = tmp_path / "evil.json"
    outside.write_text("[]")
    resp = client.post(
        "/api/sessions/open",
        json={
            "source": "custom_paths",
            "annotations_path": str(outside),
            "images_root_path": str(tmp_path),
            "model_runs": [
                {"id": "r", "name": "r", "predictions_path": str(outside)}
            ],
        },
    )
    assert resp.status_code == 400


def test_image_bytes_and_thumbnail(client: TestClient, open_custom_session) -> None:
    sid = open_custom_session["session_id"]
    resp = client.get(f"/api/sessions/{sid}/images/1/bytes")
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("image/")

    thumb = client.get(f"/api/sessions/{sid}/images/1/thumbnail", params={"max_size": 64})
    assert thumb.status_code == 200
    assert thumb.headers["content-type"] == "image/jpeg"
    # second call hits the cache and still succeeds
    assert client.get(f"/api/sessions/{sid}/images/1/thumbnail").status_code == 200


def test_missing_image_returns_404(client: TestClient, open_custom_session) -> None:
    sid = open_custom_session["session_id"]
    assert client.get(f"/api/sessions/{sid}/images/999/bytes").status_code == 404


def test_manifest_mode(dataset_root: Path) -> None:
    manifests_dir = dataset_root / "manifests"
    manifests_dir.mkdir()
    manifest = {
        "schema_version": 1,
        "id": "proj",
        "name": "Manifest Project",
        "annotations_path": str(dataset_root / "datasets" / "annotations.json"),
        "images_root_path": str(dataset_root / "datasets" / "images"),
        "model_runs": [
            {
                "id": "run_1",
                "name": "Run 1",
                "predictions_path": str(
                    dataset_root / "experiments" / "predictions.json"
                ),
            }
        ],
    }
    (manifests_dir / "proj.json").write_text(json.dumps(manifest))

    config = build_config(dataset_root, manifests_dir=manifests_dir)
    client = TestClient(create_app(config))

    listing = client.get("/api/manifests").json()
    assert listing["enabled"] is True
    assert any(m["id"] == "proj" for m in listing["manifests"])

    opened = client.post(
        "/api/sessions/open", json={"source": "manifest", "manifest_id": "proj"}
    )
    assert opened.status_code == 200, opened.text
    assert opened.json()["summary"]["images"] == 2


def test_manifest_path_outside_roots_rejected(dataset_root: Path, tmp_path: Path) -> None:
    manifests_dir = dataset_root / "manifests"
    manifests_dir.mkdir()
    outside = tmp_path / "a.json"
    outside.write_text("{}")
    manifest = {
        "id": "bad",
        "name": "Bad",
        "annotations_path": str(outside),
        "images_root_path": str(tmp_path),
        "model_runs": [{"id": "r", "name": "r", "predictions_path": str(outside)}],
    }
    (manifests_dir / "bad.json").write_text(json.dumps(manifest))
    config = build_config(dataset_root, manifests_dir=manifests_dir)
    client = TestClient(create_app(config))
    resp = client.post(
        "/api/sessions/open", json={"source": "manifest", "manifest_id": "bad"}
    )
    assert resp.status_code == 400
