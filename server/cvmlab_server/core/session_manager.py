"""Session lifecycle: open projects, parse/cache, evaluate, resolve images.

The server never persists user projects as mutable state. A "session" is an
in-memory handle over server-side parsed data plus content-hash-keyed cache
entries. Sessions are addressed by an opaque id derived from the project hash.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from ..config import ServerConfig
from . import ap_eval, coco_loader, metrics, serialization
from .cache import DiskCache
from .manifest_store import ManifestStore
from .models import CocoDataset, EvalConfig, ModelRun
from .paths import PathAccessError, PathResolver, PurePosixSafe
from .project_descriptor import (
    ModelRunDescriptor,
    ProjectDescriptor,
    project_hash,
    run_eval_hash,
)


class SessionError(Exception):
    pass


@dataclass
class Session:
    session_id: str
    descriptor: ProjectDescriptor
    project_hash: str
    images_root: str
    _dataset: Optional[CocoDataset] = None
    _model_runs: Dict[str, ModelRun] = field(default_factory=dict)
    _eval_cache: Dict[str, metrics.EvalResult] = field(default_factory=dict)

    def run_descriptor(self, run_id: str) -> ModelRunDescriptor:
        for run in self.descriptor.model_runs:
            if run.id == run_id:
                return run
        raise SessionError(f"Unknown model run: {run_id}")


def _config_key(config: EvalConfig) -> str:
    return (
        f"iou={config.iou_threshold};conf={config.confidence_threshold};"
        f"caw={int(config.class_aware_matching)};crowd={int(config.ignore_crowd)};"
        f"som={config.small_object_mode}"
    )


class SessionManager:
    def __init__(self, config: ServerConfig, resolver: PathResolver) -> None:
        self._config = config
        self._resolver = resolver
        self._cache = DiskCache(config)
        self._manifests = ManifestStore(config, resolver)
        self._sessions: Dict[str, Session] = {}

    @property
    def cache(self) -> DiskCache:
        return self._cache

    @property
    def manifests(self) -> ManifestStore:
        return self._manifests

    @property
    def custom_paths_enabled(self) -> bool:
        return self._config.custom_server_paths.enabled

    # --- opening ---

    def open_manifest(self, manifest_id: str) -> dict:
        descriptor = self._manifests.get_descriptor(manifest_id)
        return self._open(descriptor)

    def open_custom_paths(
        self,
        name: str,
        annotations_path: str,
        images_root_path: str,
        model_runs: List[dict],
    ) -> dict:
        if not self.custom_paths_enabled:
            raise SessionError("Custom server paths are disabled on this server")
        annotations = self._validate(annotations_path, "annotations_path")
        images_root = self._validate(images_root_path, "images_root_path")
        runs: List[ModelRunDescriptor] = []
        for entry in model_runs:
            preds = self._validate(entry.get("predictions_path"), "predictions_path")
            ap_path = entry.get("ap_metrics_path")
            ap_resolved = self._validate(ap_path, "ap_metrics_path") if ap_path else None
            runs.append(
                ModelRunDescriptor(
                    id=str(entry.get("id") or f"run_{len(runs) + 1}"),
                    name=str(entry.get("name") or "Model run"),
                    predictions_path=preds,
                    ap_metrics_path=ap_resolved,
                )
            )
        if not runs:
            raise SessionError("At least one model run is required")
        descriptor = ProjectDescriptor(
            name=name or "Remote project",
            annotations_path=annotations,
            images_root_path=images_root,
            model_runs=runs,
            source="custom_paths",
        )
        return self._open(descriptor)

    def _validate(self, raw_path: Optional[str], label: str) -> str:
        if not raw_path:
            raise SessionError(f"Missing {label}")
        try:
            return self._resolver.resolve_absolute(raw_path).abs_path
        except PathAccessError as exc:
            raise SessionError(f"{label} is outside allowed roots") from exc

    def _open(self, descriptor: ProjectDescriptor) -> dict:
        phash = project_hash(descriptor)
        session_id = phash
        session = Session(
            session_id=session_id,
            descriptor=descriptor,
            project_hash=phash,
            images_root=descriptor.images_root_path,
        )
        self._sessions[session_id] = session
        dataset = self._dataset(session)
        missing = self._count_missing_images(session, dataset)
        return {
            "session_id": session_id,
            "project_hash": phash,
            "name": descriptor.name,
            "source": descriptor.source,
            "manifest_id": descriptor.manifest_id,
            "model_runs": [
                {"id": r.id, "name": r.name} for r in descriptor.model_runs
            ],
            "summary": {
                "images": len(dataset.images_by_id),
                "categories": len(dataset.categories_by_id),
                "annotations": len(dataset.annotations),
                "model_runs": len(descriptor.model_runs),
                "missing_images": missing,
            },
        }

    # --- access ---

    def get_session(self, session_id: str) -> Session:
        session = self._sessions.get(session_id)
        if session is None:
            raise SessionError("Session not found. Re-open the remote project.")
        return session

    def _dataset(self, session: Session) -> CocoDataset:
        if session._dataset is None:
            try:
                with open(session.descriptor.annotations_path, "rb") as handle:
                    session._dataset = coco_loader.load_annotations(handle.read())
            except OSError as exc:
                raise SessionError(f"Could not read annotations: {exc}") from exc
        return session._dataset

    def dataset(self, session: Session) -> CocoDataset:
        return self._dataset(session)

    def model_run(self, session: Session, run_id: str) -> ModelRun:
        if run_id not in session._model_runs:
            descriptor = session.run_descriptor(run_id)
            dataset = self._dataset(session)
            try:
                with open(descriptor.predictions_path, "rb") as handle:
                    session._model_runs[run_id] = coco_loader.load_predictions(
                        handle.read(), dataset, descriptor.id, descriptor.name
                    )
            except OSError as exc:
                raise SessionError(f"Could not read predictions: {exc}") from exc
        return session._model_runs[run_id]

    def _count_missing_images(self, session: Session, dataset: CocoDataset) -> int:
        missing = 0
        for image in dataset.images_by_id.values():
            try:
                path = self._image_abs_path(session, image.file_name)
            except (PathAccessError, SessionError):
                missing += 1
                continue
            if not os.path.isfile(path):
                missing += 1
        return missing

    def _image_abs_path(self, session: Session, file_name: str) -> str:
        safe = PurePosixSafe(file_name).value
        candidate = os.path.realpath(os.path.join(session.images_root, safe))
        root = os.path.realpath(session.images_root)
        if candidate != root and os.path.commonpath([candidate, root]) != root:
            raise PathAccessError("Image path escapes images root")
        # Defense in depth: ensure still inside an allowed root.
        self._resolver.resolve_absolute(candidate)
        return candidate

    def image_path_by_id(self, session: Session, image_id: int) -> Optional[str]:
        dataset = self._dataset(session)
        image = dataset.images_by_id.get(image_id)
        if image is None:
            return None
        try:
            path = self._image_abs_path(session, image.file_name)
        except (PathAccessError, SessionError):
            return None
        return path if os.path.isfile(path) else None

    # --- evaluation ---

    def evaluate(
        self, session: Session, run_id: str, config: EvalConfig
    ) -> metrics.EvalResult:
        key = _config_key(config)
        cache_key = f"{run_id}:{key}"
        if cache_key in session._eval_cache:
            return session._eval_cache[cache_key]
        dataset = self._dataset(session)
        model_run = self.model_run(session, run_id)
        result = metrics.evaluate(dataset, model_run, config)
        session._eval_cache[cache_key] = result
        return result

    def eval_compact_json(
        self, session: Session, run_id: str, config: EvalConfig
    ) -> dict:
        disk_key = run_eval_hash(session.project_hash, run_id, _config_key(config))
        cached = self._cache.read_json(f"eval_{disk_key}")
        if cached is not None:
            return cached
        result = self.evaluate(session, run_id, config)
        compact = serialization.eval_result_to_compact_json(result)
        self._cache.write_json(f"eval_{disk_key}", compact)
        return compact

    def full_workspace(
        self, session: Session, run_id: str, config: EvalConfig
    ) -> dict:
        result = self.evaluate(session, run_id, config)
        dataset = self._dataset(session)
        model_run = self.model_run(session, run_id)
        return serialization.full_workspace_json(dataset, model_run, result)

    def image_detail(
        self, session: Session, run_id: str, config: EvalConfig, image_id: int
    ) -> dict:
        result = self.evaluate(session, run_id, config)
        dataset = self._dataset(session)
        model_run = self.model_run(session, run_id)
        return serialization.image_detail_json(dataset, model_run, result, image_id)

    # --- AP metrics ---

    def ap_metrics(self, session: Session, run_id: str, *, force: bool = False) -> dict:
        descriptor = session.run_descriptor(run_id)
        cache_key = f"ap_{session.project_hash}_{run_id}"
        if not force:
            cached = self._cache.read_json(cache_key)
            if cached is not None:
                return cached
        if descriptor.ap_metrics_path:
            result = ap_eval.load_ap_metrics_file(descriptor.ap_metrics_path)
        else:
            result = ap_eval.run_ap_eval(
                session.descriptor.annotations_path, descriptor.predictions_path
            )
        self._cache.write_json(cache_key, result)
        return result

    def import_ap_metrics(self, session: Session, run_id: str) -> dict:
        descriptor = session.run_descriptor(run_id)
        if not descriptor.ap_metrics_path:
            raise SessionError("This model run has no ap_metrics_path to import")
        result = ap_eval.load_ap_metrics_file(descriptor.ap_metrics_path)
        self._cache.write_json(f"ap_{session.project_hash}_{run_id}", result)
        return result
