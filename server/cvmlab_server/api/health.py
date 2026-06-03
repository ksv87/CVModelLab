"""Health and client-config endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Request

from .. import __version__
from ..auth import require_api_key

router = APIRouter(dependencies=[Depends(require_api_key)])


@router.get("/api/health")
async def health() -> dict:
    return {"status": "ok", "service": "cvmlab-server", "version": __version__}


@router.get("/api/config")
async def client_config(request: Request) -> dict:
    """Client-relevant flags so the UI can branch. Never exposes secrets."""
    config = request.app.state.config
    return {
        "version": __version__,
        "auth_required": config.auth_enabled,
        "manifests_enabled": config.project_manifests.enabled,
        "custom_paths_enabled": config.custom_server_paths.enabled,
        "static_web_enabled": config.static_web.enabled,
    }
