"""Server-side evaluation endpoints (hybrid mode)."""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel

from ..auth import require_api_key
from ..core.models import EvalConfig
from ..core.session_manager import SessionError

router = APIRouter(dependencies=[Depends(require_api_key)])


class EvalConfigInput(BaseModel):
    iou_threshold: float = 0.5
    confidence_threshold: float = 0.25
    class_aware_matching: bool = True
    ignore_crowd: bool = True
    small_object_mode: str = "coco"

    def to_config(self) -> EvalConfig:
        return EvalConfig(
            iou_threshold=self.iou_threshold,
            confidence_threshold=self.confidence_threshold,
            class_aware_matching=self.class_aware_matching,
            ignore_crowd=self.ignore_crowd,
            small_object_mode=self.small_object_mode,
        )


def _config_from_query(
    iou_threshold: float = Query(default=0.5),
    confidence_threshold: float = Query(default=0.25),
    class_aware_matching: bool = Query(default=True),
    ignore_crowd: bool = Query(default=True),
    small_object_mode: str = Query(default="coco"),
) -> EvalConfig:
    return EvalConfig(
        iou_threshold=iou_threshold,
        confidence_threshold=confidence_threshold,
        class_aware_matching=class_aware_matching,
        ignore_crowd=ignore_crowd,
        small_object_mode=small_object_mode,
    )


def _session(request: Request, session_id: str):
    try:
        return request.app.state.sessions.get_session(session_id)
    except SessionError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


def _compact(request: Request, session_id: str, run_id: str, config: EvalConfig) -> dict:
    manager = request.app.state.sessions
    session = _session(request, session_id)
    try:
        return manager.eval_compact_json(session, run_id, config)
    except SessionError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/api/sessions/{session_id}/eval/{run_id}")
async def run_eval(
    session_id: str, run_id: str, request: Request, body: EvalConfigInput
) -> dict:
    return _compact(request, session_id, run_id, body.to_config())


@router.get("/api/sessions/{session_id}/eval/{run_id}/summary")
async def eval_summary(
    session_id: str,
    run_id: str,
    request: Request,
    config: EvalConfig = Depends(_config_from_query),
) -> dict:
    compact = _compact(request, session_id, run_id, config)
    return {"config": compact["config"], "overall": compact["overall"]}


@router.get("/api/sessions/{session_id}/eval/{run_id}/classes")
async def eval_classes(
    session_id: str,
    run_id: str,
    request: Request,
    config: EvalConfig = Depends(_config_from_query),
) -> dict:
    compact = _compact(request, session_id, run_id, config)
    return {
        "per_class": compact["per_class"],
        "small_object": compact["small_object"],
        "confusion": compact["confusion"],
    }


_FILTERS = {
    "all": lambda s: True,
    "errors": lambda s: s["has_fp"] or s["has_fn"],
    "fp": lambda s: s["has_fp"],
    "fn": lambda s: s["has_fn"],
    "class_confusion": lambda s: s["has_class_confusion"],
    "small_object": lambda s: s["has_small_object"],
}


@router.get("/api/sessions/{session_id}/eval/{run_id}/images")
async def eval_images(
    session_id: str,
    run_id: str,
    request: Request,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=100, ge=1, le=1000),
    filter: str = Query(default="all"),
    config: EvalConfig = Depends(_config_from_query),
) -> dict:
    compact = _compact(request, session_id, run_id, config)
    predicate = _FILTERS.get(filter, _FILTERS["all"])
    summaries = [s for s in compact["image_summaries"] if predicate(s)]
    total = len(summaries)
    page = summaries[offset : offset + limit]
    # Attach file names for the list view.
    manager = request.app.state.sessions
    session = _session(request, session_id)
    dataset = manager.dataset(session)
    for item in page:
        image = dataset.images_by_id.get(item["image_id"])
        item["file_name"] = image.file_name if image else None
    return {"total": total, "offset": offset, "limit": limit, "images": page}


@router.get("/api/sessions/{session_id}/eval/{run_id}/images/{image_id}")
async def eval_image_detail(
    session_id: str,
    run_id: str,
    image_id: int,
    request: Request,
    config: EvalConfig = Depends(_config_from_query),
) -> dict:
    manager = request.app.state.sessions
    session = _session(request, session_id)
    try:
        return manager.image_detail(session, run_id, config, image_id)
    except SessionError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/api/sessions/{session_id}/eval/{run_id}/full")
async def eval_full(
    session_id: str,
    run_id: str,
    request: Request,
    config: EvalConfig = Depends(_config_from_query),
) -> dict:
    manager = request.app.state.sessions
    session = _session(request, session_id)
    try:
        return manager.full_workspace(session, run_id, config)
    except SessionError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/api/sessions/{session_id}/eval/{run_id}/report-data")
async def eval_report_data(
    session_id: str,
    run_id: str,
    request: Request,
    config: EvalConfig = Depends(_config_from_query),
) -> dict:
    manager = request.app.state.sessions
    session = _session(request, session_id)
    compact = _compact(request, session_id, run_id, config)
    ap: Optional[dict]
    try:
        ap = manager.ap_metrics(session, run_id)
    except Exception:  # noqa: BLE001 - AP is optional for reports
        ap = None
    return {
        "name": session.descriptor.name,
        "model_run": next(
            (
                {"id": r.id, "name": r.name}
                for r in session.descriptor.model_runs
                if r.id == run_id
            ),
            {"id": run_id, "name": run_id},
        ),
        "eval": compact,
        "ap_metrics": ap,
    }
