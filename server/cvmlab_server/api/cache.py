"""Cache management endpoint."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Request

from ..auth import require_api_key

router = APIRouter(dependencies=[Depends(require_api_key)])


@router.post("/api/cache/clear")
async def clear_cache(request: Request) -> dict:
    request.app.state.sessions.cache.clear()
    return {"status": "cleared"}
