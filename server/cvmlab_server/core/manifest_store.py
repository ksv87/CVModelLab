"""Server-side project manifests (admin-configured, read-only)."""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import List, Optional

import orjson

from ..config import ServerConfig
from .paths import PathAccessError, PathResolver
from .project_descriptor import ModelRunDescriptor, ProjectDescriptor


class ManifestError(Exception):
    pass


@dataclass(frozen=True)
class ManifestSummary:
    id: str
    name: str


class ManifestStore:
    def __init__(self, config: ServerConfig, resolver: PathResolver) -> None:
        self._config = config
        self._resolver = resolver
        self._enabled = config.project_manifests.enabled
        self._directory = (
            config.resolve_relative(config.project_manifests.directory)
            if config.project_manifests.directory
            else None
        )

    @property
    def enabled(self) -> bool:
        return self._enabled and self._directory is not None

    def list_manifests(self) -> List[ManifestSummary]:
        if not self.enabled:
            return []
        summaries: List[ManifestSummary] = []
        try:
            names = sorted(os.listdir(self._directory))
        except OSError:
            return []
        for name in names:
            if not name.lower().endswith(".json"):
                continue
            try:
                descriptor = self._load_raw(name)
            except ManifestError:
                continue
            summaries.append(
                ManifestSummary(
                    id=str(descriptor.get("id") or name[:-5]),
                    name=str(descriptor.get("name") or descriptor.get("id") or name),
                )
            )
        return summaries

    def get_descriptor(self, manifest_id: str) -> ProjectDescriptor:
        if not self.enabled:
            raise ManifestError("Manifests are not enabled")
        raw = self._find_manifest(manifest_id)
        return self._to_descriptor(manifest_id, raw)

    # --- internals ---

    def _find_manifest(self, manifest_id: str) -> dict:
        try:
            names = os.listdir(self._directory)
        except OSError as exc:
            raise ManifestError("Manifest directory unavailable") from exc
        for name in names:
            if not name.lower().endswith(".json"):
                continue
            raw = self._load_raw(name)
            if str(raw.get("id") or name[:-5]) == manifest_id:
                return raw
        raise ManifestError(f"Manifest not found: {manifest_id}")

    def _load_raw(self, file_name: str) -> dict:
        # Confine reads to the manifest directory.
        full = os.path.realpath(os.path.join(self._directory, file_name))
        root = os.path.realpath(self._directory)
        if full != root and os.path.commonpath([full, root]) != root:
            raise ManifestError("Manifest path escapes manifest directory")
        try:
            with open(full, "rb") as handle:
                data = orjson.loads(handle.read())
        except (OSError, orjson.JSONDecodeError) as exc:
            raise ManifestError(f"Invalid manifest: {file_name}") from exc
        if not isinstance(data, dict):
            raise ManifestError(f"Manifest must be an object: {file_name}")
        return data

    def _validate_path(self, raw_path: object, label: str) -> str:
        if not isinstance(raw_path, str) or not raw_path:
            raise ManifestError(f"Manifest missing {label}")
        try:
            resolved = self._resolver.resolve_absolute(raw_path)
        except PathAccessError as exc:
            raise ManifestError(
                f"Manifest {label} is outside allowed roots: {raw_path}"
            ) from exc
        return resolved.abs_path

    def _optional_path(self, raw_path: object, label: str) -> Optional[str]:
        if raw_path is None:
            return None
        return self._validate_path(raw_path, label)

    def _to_descriptor(self, manifest_id: str, raw: dict) -> ProjectDescriptor:
        annotations = self._validate_path(raw.get("annotations_path"), "annotations_path")
        images_root = self._validate_path(raw.get("images_root_path"), "images_root_path")
        runs_raw = raw.get("model_runs")
        if not isinstance(runs_raw, list) or not runs_raw:
            raise ManifestError("Manifest must list at least one model run")
        runs: List[ModelRunDescriptor] = []
        for entry in runs_raw:
            if not isinstance(entry, dict):
                raise ManifestError("Invalid model run entry in manifest")
            runs.append(
                ModelRunDescriptor(
                    id=str(entry.get("id") or ""),
                    name=str(entry.get("name") or entry.get("id") or "Model run"),
                    predictions_path=self._validate_path(
                        entry.get("predictions_path"), "predictions_path"
                    ),
                    ap_metrics_path=self._optional_path(
                        entry.get("ap_metrics_path"), "ap_metrics_path"
                    ),
                )
            )
        return ProjectDescriptor(
            name=str(raw.get("name") or manifest_id),
            annotations_path=annotations,
            images_root_path=images_root,
            model_runs=runs,
            source="manifest",
            manifest_id=manifest_id,
        )
