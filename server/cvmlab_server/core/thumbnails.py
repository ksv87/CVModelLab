"""Lazy thumbnail generation with on-disk caching (Pillow)."""

from __future__ import annotations

import hashlib
import io
import os
from pathlib import Path
from typing import Optional

from .cache import DiskCache


def _thumb_key(abs_path: str, max_size: int) -> str:
    try:
        mtime = os.stat(abs_path).st_mtime_ns
    except OSError:
        mtime = 0
    raw = f"{abs_path}:{mtime}:{max_size}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:32]


def get_thumbnail(cache: DiskCache, abs_path: str, max_size: int) -> Optional[bytes]:
    """Return JPEG thumbnail bytes for ``abs_path``, generating lazily.

    Thumbnails are generated on demand only; the server never pre-generates
    thumbnails for an entire dataset.
    """
    if max_size <= 0:
        max_size = 256
    max_size = min(max_size, 1024)

    cached_path = cache.thumbnail_path(_thumb_key(abs_path, max_size))
    if cached_path is not None and cached_path.exists():
        try:
            return cached_path.read_bytes()
        except OSError:
            pass

    from PIL import Image

    try:
        with Image.open(abs_path) as image:
            image = image.convert("RGB")
            image.thumbnail((max_size, max_size))
            buffer = io.BytesIO()
            image.save(buffer, format="JPEG", quality=82)
            data = buffer.getvalue()
    except (OSError, ValueError):
        return None

    if cached_path is not None:
        try:
            cached_path.write_bytes(data)
        except OSError:
            pass
    return data
