"""Stable project descriptors and content-based hashing for caching."""

from __future__ import annotations

import hashlib
import os
from dataclasses import dataclass
from typing import List, Optional


@dataclass(frozen=True)
class ModelRunDescriptor:
    id: str
    name: str
    predictions_path: str
    ap_metrics_path: Optional[str] = None


@dataclass(frozen=True)
class ProjectDescriptor:
    name: str
    annotations_path: str
    images_root_path: str
    model_runs: List[ModelRunDescriptor]
    source: str = "custom_paths"
    manifest_id: Optional[str] = None


def _file_signature(path: str) -> str:
    try:
        stat = os.stat(path)
        return f"{path}:{stat.st_mtime_ns}:{stat.st_size}"
    except OSError:
        return f"{path}:missing"


def project_hash(descriptor: ProjectDescriptor) -> str:
    parts = [_file_signature(descriptor.annotations_path), descriptor.images_root_path]
    for run in descriptor.model_runs:
        parts.append(run.id)
        parts.append(_file_signature(run.predictions_path))
        if run.ap_metrics_path:
            parts.append(_file_signature(run.ap_metrics_path))
    digest = hashlib.sha256("|".join(parts).encode("utf-8")).hexdigest()
    return digest[:32]


def run_eval_hash(
    project_hash_value: str, model_run_id: str, eval_config_key: str
) -> str:
    raw = f"{project_hash_value}:{model_run_id}:{eval_config_key}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:32]
