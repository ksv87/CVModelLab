"""Simple on-disk cache for parsed indexes, eval results, AP, and thumbnails.

The cache is the only durable state the server writes (besides logs). It is
keyed by content-stable hashes and can be cleared wholesale.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path
from typing import Optional

import orjson

from ..config import ServerConfig


class DiskCache:
    def __init__(self, config: ServerConfig) -> None:
        self._enabled = config.cache.enabled
        self._root = Path(config.resolve_relative(config.cache.directory))
        self._thumbnails_enabled = config.cache.thumbnails
        if self._enabled:
            self._ensure_dir(self._root)
            self._ensure_dir(self._root / "json")
            self._ensure_dir(self._root / "thumbnails")

    @staticmethod
    def _ensure_dir(path: Path) -> None:
        try:
            path.mkdir(parents=True, exist_ok=True)
        except OSError:
            pass

    @property
    def enabled(self) -> bool:
        return self._enabled

    @property
    def thumbnails_enabled(self) -> bool:
        return self._enabled and self._thumbnails_enabled

    def read_json(self, key: str) -> Optional[dict]:
        if not self._enabled:
            return None
        path = self._root / "json" / f"{key}.json"
        if not path.exists():
            return None
        try:
            return orjson.loads(path.read_bytes())
        except (OSError, orjson.JSONDecodeError):
            return None

    def write_json(self, key: str, value: dict) -> None:
        if not self._enabled:
            return
        path = self._root / "json" / f"{key}.json"
        try:
            path.write_bytes(orjson.dumps(value))
        except OSError:
            pass

    def thumbnail_path(self, key: str) -> Optional[Path]:
        if not self.thumbnails_enabled:
            return None
        return self._root / "thumbnails" / f"{key}.jpg"

    def clear(self) -> None:
        if not self._enabled:
            return
        for sub in ("json", "thumbnails"):
            target = self._root / sub
            if target.exists():
                shutil.rmtree(target, ignore_errors=True)
            self._ensure_dir(target)
