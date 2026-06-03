"""Shared pytest fixtures: a tiny synthetic COCO dataset on disk + clients."""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from cvmlab_server.config import (
    AllowedRoot,
    CustomServerPathsConfig,
    ProjectManifestsConfig,
    ServerConfig,
)
from cvmlab_server.main import create_app

# A minimal COCO dataset: 2 images, 2 categories, a few annotations.
_ANNOTATIONS = {
    "images": [
        {"id": 1, "file_name": "img1.png", "width": 100, "height": 100},
        {"id": 2, "file_name": "img2.png", "width": 100, "height": 100},
    ],
    "categories": [
        {"id": 1, "name": "cat"},
        {"id": 2, "name": "dog"},
    ],
    "annotations": [
        {"id": 1, "image_id": 1, "category_id": 1, "bbox": [10, 10, 20, 20],
         "area": 400, "iscrowd": 0},
        {"id": 2, "image_id": 1, "category_id": 2, "bbox": [50, 50, 30, 30],
         "area": 900, "iscrowd": 0},
        {"id": 3, "image_id": 2, "category_id": 1, "bbox": [10, 10, 10, 10],
         "area": 100, "iscrowd": 0},
    ],
}

# Predictions: one good match, one wrong class, one missed (no pred for ann 3).
_PREDICTIONS = [
    {"image_id": 1, "category_id": 1, "bbox": [11, 11, 20, 20], "score": 0.9},
    {"image_id": 1, "category_id": 1, "bbox": [50, 50, 30, 30], "score": 0.8},
]


@pytest.fixture
def dataset_root(tmp_path: Path) -> Path:
    datasets = tmp_path / "datasets"
    images = datasets / "images"
    images.mkdir(parents=True)
    (datasets / "annotations.json").write_text(json.dumps(_ANNOTATIONS))

    experiments = tmp_path / "experiments"
    experiments.mkdir(parents=True)
    (experiments / "predictions.json").write_text(json.dumps(_PREDICTIONS))

    for name in ("img1.png", "img2.png"):
        Image.new("RGB", (100, 100), color=(120, 130, 140)).save(images / name)

    return tmp_path


def build_config(root: Path, *, api_key=None, manifests_dir=None) -> ServerConfig:
    return ServerConfig(
        api_key=api_key,
        allowed_roots=[
            AllowedRoot(id="datasets", path=str(root / "datasets"), label="Datasets"),
            AllowedRoot(
                id="experiments",
                path=str(root / "experiments"),
                label="Experiments",
            ),
        ],
        custom_server_paths=CustomServerPathsConfig(enabled=True),
        project_manifests=ProjectManifestsConfig(
            enabled=manifests_dir is not None,
            directory=str(manifests_dir) if manifests_dir else None,
        ),
        base_dir=str(root),
    )


@pytest.fixture
def config(dataset_root: Path) -> ServerConfig:
    return build_config(dataset_root)


@pytest.fixture
def client(config: ServerConfig) -> TestClient:
    return TestClient(create_app(config))


@pytest.fixture
def open_custom_session(client: TestClient, dataset_root: Path):
    """Open a custom-paths session and return its JSON body."""
    response = client.post(
        "/api/sessions/open",
        json={
            "source": "custom_paths",
            "name": "Test project",
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
        },
    )
    assert response.status_code == 200, response.text
    return response.json()
