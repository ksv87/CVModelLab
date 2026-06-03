"""Static serving of the Flutter Web/PWA build.

Serves ``static_web.root`` with an SPA fallback to ``index.html`` for client
routes, while keeping ``/api/*`` owned by the API routers. If the build is
missing, the root shows a helpful message and the API keeps working.
"""

from __future__ import annotations

import os

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse, Response

router = APIRouter()

_MISSING_BUILD_HTML = """<!doctype html>
<html><head><meta charset="utf-8"><title>CV Model Lab Server</title></head>
<body style="font-family: sans-serif; max-width: 40rem; margin: 3rem auto;">
<h1>CV Model Lab Server</h1>
<p>The API is running, but the Flutter Web build was not found.</p>
<p>Run <code>flutter build web</code> and point <code>static_web.root</code>
at <code>build/web</code>, then restart the server.</p>
<p><a href="/api/health">/api/health</a></p>
</body></html>
"""


def _web_root(request: Request) -> str:
    config = request.app.state.config
    return config.resolve_relative(config.static_web.root)


def _serve_path(web_root: str, rel: str) -> Response:
    # Normalize and confine to the web root (defense in depth).
    full = os.path.realpath(os.path.join(web_root, rel))
    root_real = os.path.realpath(web_root)
    if full != root_real and os.path.commonpath([full, root_real]) != root_real:
        raise HTTPException(status_code=404)
    if os.path.isfile(full):
        return FileResponse(full)
    raise FileNotFoundError(rel)


@router.get("/", include_in_schema=False)
async def index(request: Request) -> Response:
    if not request.app.state.config.static_web.enabled:
        return HTMLResponse(_MISSING_BUILD_HTML)
    web_root = _web_root(request)
    index_path = os.path.join(web_root, "index.html")
    if os.path.isfile(index_path):
        return FileResponse(index_path)
    return HTMLResponse(_MISSING_BUILD_HTML, status_code=200)


@router.get("/{full_path:path}", include_in_schema=False)
async def spa_fallback(full_path: str, request: Request) -> Response:
    config = request.app.state.config
    if not config.static_web.enabled or full_path.startswith("api/"):
        raise HTTPException(status_code=404)
    web_root = _web_root(request)
    try:
        return _serve_path(web_root, full_path)
    except FileNotFoundError:
        pass
    # SPA fallback to index.html for client-side routes.
    index_path = os.path.join(web_root, "index.html")
    if os.path.isfile(index_path):
        return FileResponse(index_path)
    raise HTTPException(status_code=404)
