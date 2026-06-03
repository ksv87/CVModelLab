"""Server manifest listing."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request

from ..auth import require_api_key
from ..core.manifest_store import ManifestError

router = APIRouter(dependencies=[Depends(require_api_key)])


@router.get("/api/manifests")
async def list_manifests(request: Request) -> dict:
    store = request.app.state.sessions.manifests
    return {
        "enabled": store.enabled,
        "manifests": [
            {"id": m.id, "name": m.name} for m in store.list_manifests()
        ],
    }


@router.get("/api/manifests/{manifest_id}")
async def get_manifest(manifest_id: str, request: Request) -> dict:
    store = request.app.state.sessions.manifests
    try:
        descriptor = store.get_descriptor(manifest_id)
    except ManifestError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return {
        "id": descriptor.manifest_id,
        "name": descriptor.name,
        "model_runs": [
            {"id": r.id, "name": r.name} for r in descriptor.model_runs
        ],
    }
