"""Allowed-roots file browser."""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request

from ..auth import require_api_key
from ..core.paths import PathAccessError, PathResolver

router = APIRouter(dependencies=[Depends(require_api_key)])

_JSON_SUFFIX = ".json"


def _resolver(request: Request) -> PathResolver:
    return request.app.state.resolver


@router.get("/api/roots")
async def list_roots(request: Request) -> dict:
    resolver = _resolver(request)
    return {
        "roots": [
            {"id": root.id, "label": root.label}
            for root in resolver.list_roots()
        ]
    }


@router.get("/api/browse")
async def browse(
    request: Request,
    root_id: str = Query(...),
    path: str = Query(default=""),
    files: str = Query(
        default="all",
        description="Filter files: 'all' or 'json' (directories are always listed).",
    ),
) -> dict:
    resolver = _resolver(request)
    try:
        resolved = resolver.resolve_within_root(root_id, path)
    except PathAccessError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    if not os.path.isdir(resolved.abs_path):
        raise HTTPException(status_code=404, detail="Directory not found")

    entries = []
    with os.scandir(resolved.abs_path) as scan:
        for item in scan:
            try:
                is_dir = item.is_dir(follow_symlinks=False)
            except OSError:
                continue
            rel = (
                f"{resolved.rel_path}/{item.name}"
                if resolved.rel_path
                else item.name
            )
            if is_dir:
                entries.append(
                    {"name": item.name, "path": rel, "kind": "directory"}
                )
                continue
            if not item.is_file(follow_symlinks=False):
                continue
            if files == "json" and not item.name.lower().endswith(_JSON_SUFFIX):
                continue
            stat = item.stat(follow_symlinks=False)
            entries.append(
                {
                    "name": item.name,
                    "path": rel,
                    "kind": "file",
                    "size_bytes": stat.st_size,
                    "modified_at": _iso(stat.st_mtime),
                }
            )

    entries.sort(key=lambda e: (e["kind"] != "directory", e["name"].lower()))
    return {
        "root_id": resolved.root_id,
        "path": resolved.rel_path,
        "abs_path": resolved.abs_path,
        "entries": entries,
    }


def _iso(mtime: float) -> Optional[str]:
    try:
        return datetime.fromtimestamp(mtime, tz=timezone.utc).isoformat()
    except (OverflowError, OSError, ValueError):
        return None
