"""Image bytes and lazy thumbnails."""

from __future__ import annotations

import mimetypes

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import FileResponse, Response

from ..auth import require_api_key
from ..core.session_manager import SessionError
from ..core.thumbnails import get_thumbnail

router = APIRouter(dependencies=[Depends(require_api_key)])


def _session(request: Request, session_id: str):
    try:
        return request.app.state.sessions.get_session(session_id)
    except SessionError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/api/sessions/{session_id}/images/{image_id}/bytes")
async def image_bytes(session_id: str, image_id: int, request: Request) -> Response:
    manager = request.app.state.sessions
    session = _session(request, session_id)
    path = manager.image_path_by_id(session, image_id)
    if path is None:
        raise HTTPException(status_code=404, detail="Image not found")
    media_type, _ = mimetypes.guess_type(path)
    return FileResponse(path, media_type=media_type or "application/octet-stream")


@router.get("/api/sessions/{session_id}/images/{image_id}/thumbnail")
async def image_thumbnail(
    session_id: str,
    image_id: int,
    request: Request,
    max_size: int = Query(default=256, ge=16, le=1024),
) -> Response:
    manager = request.app.state.sessions
    session = _session(request, session_id)
    path = manager.image_path_by_id(session, image_id)
    if path is None:
        raise HTTPException(status_code=404, detail="Image not found")
    data = get_thumbnail(manager.cache, path, max_size)
    if data is None:
        raise HTTPException(status_code=404, detail="Could not render thumbnail")
    return Response(content=data, media_type="image/jpeg")
