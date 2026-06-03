"""FastAPI application assembly and CLI entry point."""

from __future__ import annotations

import argparse
import logging
import os
import re
import sys
from pathlib import Path
from typing import List, Optional

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from . import __version__
from .auth import StartupAborted, check_startup_auth, describe_auth
from .config import ServerConfig, load_config
from .core.paths import PathResolver
from .core.session_manager import SessionManager

logger = logging.getLogger("cvmlab_server")


class BodySizeLimitMiddleware(BaseHTTPMiddleware):
    """Reject oversized request bodies based on Content-Length."""

    def __init__(self, app, max_bytes: int) -> None:
        super().__init__(app)
        self._max_bytes = max_bytes

    async def dispatch(self, request: Request, call_next):
        content_length = request.headers.get("content-length")
        if content_length is not None:
            try:
                if int(content_length) > self._max_bytes:
                    return JSONResponse(
                        status_code=413,
                        content={"detail": "Request body too large"},
                    )
            except ValueError:
                pass
        return await call_next(request)


def _cors_regex(origins: List[str]) -> Optional[str]:
    """Build an allow_origin_regex from glob-like origin patterns."""
    if not origins:
        return None
    parts = []
    for origin in origins:
        escaped = re.escape(origin).replace(r"\*", r"[^/]*")
        parts.append(escaped)
    return "^(" + "|".join(parts) + ")$"


def create_app(config: ServerConfig) -> FastAPI:
    app = FastAPI(title="CV Model Lab Server", version=__version__)
    app.state.config = config
    app.state.resolver = PathResolver(config)
    app.state.sessions = SessionManager(config, app.state.resolver)

    if config.cors.enabled:
        regex = _cors_regex(config.cors.allowed_origins)
        app.add_middleware(
            CORSMiddleware,
            allow_origins=[],
            allow_origin_regex=regex,
            allow_credentials=False,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    app.add_middleware(
        BodySizeLimitMiddleware,
        max_bytes=config.max_request_body_mb * 1024 * 1024,
    )

    # API routers first; the static SPA catch-all must be registered last.
    from .api import (
        ap_metrics,
        browse,
        cache,
        evaluation,
        health,
        images,
        manifests,
        sessions,
        static,
    )

    app.include_router(health.router)
    app.include_router(browse.router)
    app.include_router(manifests.router)
    app.include_router(sessions.router)
    app.include_router(images.router)
    app.include_router(ap_metrics.router)
    app.include_router(evaluation.router)
    app.include_router(cache.router)
    app.include_router(static.router)
    return app


def _setup_logging(config: ServerConfig) -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    log_dir = config.resolve_relative(config.logs.directory)
    try:
        Path(log_dir).mkdir(parents=True, exist_ok=True)
        handler = logging.FileHandler(os.path.join(log_dir, "cvmlab-server.log"))
        handler.setFormatter(
            logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s")
        )
        logging.getLogger().addHandler(handler)
    except OSError as exc:
        logger.warning("Could not set up file logging in %s: %s", log_dir, exc)


def run_cli(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="CV Model Lab server")
    parser.add_argument("--config", help="Path to server config YAML")
    parser.add_argument("--host", help="Override host")
    parser.add_argument("--port", type=int, help="Override port")
    parser.add_argument(
        "--allow-unauthenticated",
        action="store_true",
        help="Allow open-access startup without an API key (non-interactive).",
    )
    args = parser.parse_args(argv)

    try:
        config = load_config(args.config)
    except (FileNotFoundError, ValueError) as exc:
        print(f"Config error: {exc}", file=sys.stderr)
        return 2

    if args.host:
        config.host = args.host
    if args.port:
        config.port = args.port

    _setup_logging(config)

    try:
        check_startup_auth(
            config, allow_unauthenticated=args.allow_unauthenticated
        )
    except StartupAborted as exc:
        print(str(exc), file=sys.stderr)
        return 3

    logger.info(describe_auth(config))
    logger.info(
        "Allowed roots: %s",
        ", ".join(root.id for root in config.allowed_roots) or "(none)",
    )

    import uvicorn

    app = create_app(config)
    uvicorn.run(app, host=config.host, port=config.port)
    return 0


if __name__ == "__main__":
    raise SystemExit(run_cli())
