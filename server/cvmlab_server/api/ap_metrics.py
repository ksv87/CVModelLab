"""COCO AP metrics endpoints (run / get / import)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request

from ..auth import require_api_key
from ..core.ap_eval import ApEvalError
from ..core.session_manager import SessionError

router = APIRouter(dependencies=[Depends(require_api_key)])


def _session(request: Request, session_id: str):
    try:
        return request.app.state.sessions.get_session(session_id)
    except SessionError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/api/sessions/{session_id}/ap/{run_id}/run")
async def run_ap(session_id: str, run_id: str, request: Request) -> dict:
    manager = request.app.state.sessions
    session = _session(request, session_id)
    try:
        return manager.ap_metrics(session, run_id, force=True)
    except (SessionError, ApEvalError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/api/sessions/{session_id}/ap/{run_id}")
async def get_ap(session_id: str, run_id: str, request: Request) -> dict:
    manager = request.app.state.sessions
    session = _session(request, session_id)
    try:
        return manager.ap_metrics(session, run_id)
    except (SessionError, ApEvalError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/api/sessions/{session_id}/ap/{run_id}/import")
async def import_ap(session_id: str, run_id: str, request: Request) -> dict:
    manager = request.app.state.sessions
    session = _session(request, session_id)
    try:
        return manager.import_ap_metrics(session, run_id)
    except (SessionError, ApEvalError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
