"""API key authentication and startup access gating."""

from __future__ import annotations

import sys
from typing import Callable, Optional

from fastapi import Header, HTTPException, Request, status

from .config import ServerConfig

API_KEY_HEADER = "X-CVML-API-Key"

_OPEN_ACCESS_WARNING = (
    "WARNING: CV Model Lab Server is starting without API key. Anyone who can "
    "reach this host can browse allowed roots and read dataset files."
)


class StartupAborted(Exception):
    """Raised when open-access startup is not confirmed."""


async def require_api_key(
    request: Request,
    x_cvml_api_key: Optional[str] = Header(default=None, alias=API_KEY_HEADER),
) -> None:
    """FastAPI dependency enforcing the API key when one is configured."""
    config: ServerConfig = request.app.state.config
    if not config.auth_enabled:
        return
    if not x_cvml_api_key or x_cvml_api_key != config.api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API key",
            headers={"WWW-Authenticate": API_KEY_HEADER},
        )


def describe_auth(config: ServerConfig) -> str:
    if config.auth_enabled:
        return "Auth: API key enabled"
    return "Auth: OPEN ACCESS, no API key configured"


def check_startup_auth(
    config: ServerConfig,
    *,
    allow_unauthenticated: bool = False,
    interactive: Optional[bool] = None,
    input_fn: Callable[[str], str] = input,
    output_fn: Callable[[str], None] = lambda message: print(message, file=sys.stderr),
) -> None:
    """Enforce the open-access policy before the server starts.

    * API key configured -> always allowed.
    * No API key + ``--allow-unauthenticated`` -> allowed with a logged warning.
    * No API key + interactive TTY -> prompt, defaulting to NO.
    * No API key + non-interactive -> raise :class:`StartupAborted`.
    """
    if config.auth_enabled:
        return

    if interactive is None:
        interactive = sys.stdin is not None and sys.stdin.isatty()

    output_fn(_OPEN_ACCESS_WARNING)

    if allow_unauthenticated:
        output_fn("Continuing in open-access mode (--allow-unauthenticated).")
        return

    if not interactive:
        raise StartupAborted(
            "Refusing to start without an API key. Set api_key in the config "
            "or pass --allow-unauthenticated to run in open-access mode."
        )

    answer = input_fn("Continue? [y/N] ").strip().lower()
    if answer not in ("y", "yes"):
        raise StartupAborted("Startup cancelled by operator.")
