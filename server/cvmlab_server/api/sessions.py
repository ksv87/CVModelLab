"""Session open endpoint (manifest or custom server paths)."""

from __future__ import annotations

from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from ..auth import require_api_key
from ..core.manifest_store import ManifestError
from ..core.session_manager import SessionError

router = APIRouter(dependencies=[Depends(require_api_key)])


class ModelRunInput(BaseModel):
    id: Optional[str] = None
    name: Optional[str] = None
    predictions_path: str
    ap_metrics_path: Optional[str] = None


class OpenSessionRequest(BaseModel):
    source: str
    # manifest mode
    manifest_id: Optional[str] = None
    # custom_paths mode
    name: Optional[str] = None
    annotations_path: Optional[str] = None
    images_root_path: Optional[str] = None
    model_runs: List[ModelRunInput] = []


@router.post("/api/sessions/open")
async def open_session(request: Request, body: OpenSessionRequest) -> dict:
    manager = request.app.state.sessions
    try:
        if body.source == "manifest":
            if not body.manifest_id:
                raise HTTPException(status_code=400, detail="manifest_id is required")
            return manager.open_manifest(body.manifest_id)
        if body.source == "custom_paths":
            if not body.annotations_path or not body.images_root_path:
                raise HTTPException(
                    status_code=400,
                    detail="annotations_path and images_root_path are required",
                )
            return manager.open_custom_paths(
                name=body.name or "Remote project",
                annotations_path=body.annotations_path,
                images_root_path=body.images_root_path,
                model_runs=[run.model_dump() for run in body.model_runs],
            )
        raise HTTPException(status_code=400, detail=f"Unknown source: {body.source}")
    except (SessionError, ManifestError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
